"""How a trained GolfSeg is actually asked, once, in one place.

Three techniques live here, and the reason they share a file is that every
caller — the evaluation harness, the FastAPI service, the sweep — must ask the
model the same way, or a checkpoint that measured well ships behind an
inference path that was never measured.

**Dihedral test-time augmentation.** A golf hole runs in any direction, which
is why training rotates every patch (§43). Inference deserves the same
humility: the eight flips and right-angle rotations are averaged, in
probability space, and the answer stops depending on which way north happened
to be. Measured on the held-out test courses, this is worth about a point of
mean IoU for eight times the compute — a trade the sweep, which runs offline
on an A100, takes without noticing.

**Gaussian window blending.** Tiled inference used to average overlapping
windows uniformly, but a pixel at a window's edge has seen half its context;
one at the centre has seen all of it. Weighting each window by a Gaussian
lets the confident centres dominate and the blind edges defer, which is the
difference between a seam down a fairway and no seam.

**Ensembling.** Checkpoints disagree most exactly where they are least
reliable, so averaging several is a cheap way to be wrong less often.
Averaging happens in probability space, never logits — different training
runs scale their logits differently, and averaging them would let the
loudest model win rather than the most right one. Members may differ in
input width (a three-channel weight from before the NAIP corpus, a
four-channel one after); each is shown the slice it expects.
"""

from __future__ import annotations

import torch

#: The eight symmetries of the square, as (k quarter-turns, horizontal flip).
#: Applying rot90(k) then flip, and undoing them in reverse order, is the
#: identity — the test suite holds this file to that.
_DIHEDRAL: tuple[tuple[int, bool], ...] = (
    (0, False), (1, False), (2, False), (3, False),
    (0, True), (1, True), (2, True), (3, True),
)


def _apply(pixels: torch.Tensor, quarter_turns: int, flip: bool) -> torch.Tensor:
    if flip:
        pixels = torch.flip(pixels, dims=(-1,))
    if quarter_turns:
        pixels = torch.rot90(pixels, k=quarter_turns, dims=(-2, -1))
    return pixels


def _undo(pixels: torch.Tensor, quarter_turns: int, flip: bool) -> torch.Tensor:
    if quarter_turns:
        pixels = torch.rot90(pixels, k=-quarter_turns, dims=(-2, -1))
    if flip:
        pixels = torch.flip(pixels, dims=(-1,))
    return pixels


def _shown(pixels: torch.Tensor, model) -> torch.Tensor:
    """The slice of the input this member actually accepts.

    The corpus is built four channels wide (§NAIP); a pre-NAIP checkpoint is
    three. The colour bands come first in both layouts, so a narrower model
    is shown the leading slice rather than being refused.
    """
    wanted = getattr(model, "in_channels", None)
    if wanted is None or pixels.shape[1] == wanted:
        return pixels
    if pixels.shape[1] > wanted:
        return pixels[:, :wanted]
    raise ValueError(
        f"model wants {wanted} channels, input has {pixels.shape[1]}")


def predict_probabilities(models, pixels: torch.Tensor, device,
                          *, tta: bool = True) -> torch.Tensor:
    """Class probabilities for one window, [C, H, W] on the CPU.

    `models` is one model or a sequence; every member sees every TTA view, and
    everything is averaged in probability space.
    """
    if not isinstance(models, (list, tuple)):
        models = [models]

    views = _DIHEDRAL if tta else _DIHEDRAL[:1]
    total: torch.Tensor | None = None
    with torch.no_grad():
        for model in models:
            shown = _shown(pixels, model)
            for quarter_turns, flip in views:
                logits = model(_apply(shown, quarter_turns, flip).to(device))
                probabilities = torch.softmax(logits[0].float(), dim=0)
                probabilities = _undo(probabilities, quarter_turns, flip).cpu()
                total = probabilities if total is None else total + probabilities
    return total / (len(models) * len(views))


def gaussian_window(tile: int, device=None) -> torch.Tensor:
    """A [1, tile, tile] weight, high in the centre, low at the blind edges.

    sigma of a quarter tile leaves the centre near 1 and the corners near
    0.03 — enough that an edge pixel's vote is a whisper without ever being
    zero, because the outermost windows have no neighbour to defer to.
    """
    sigma = tile / 4.0
    axis = torch.arange(tile, dtype=torch.float32, device=device) - (tile - 1) / 2.0
    one_dimensional = torch.exp(-(axis ** 2) / (2 * sigma ** 2))
    return (one_dimensional[:, None] * one_dimensional[None, :]).unsqueeze(0)


def infer_tiled(models, tensor: torch.Tensor, device, *, tile: int = 512,
                overlap: float = 0.25, tta: bool = True) -> torch.Tensor:
    """Class probabilities for a whole stitched image, [C, H, W].

    Overlapping windows, each weighted by `gaussian_window`, each answered by
    `predict_probabilities`. The return is a probability map (it sums to one
    per pixel), not logits — callers argmax it or read confidences directly.
    """
    if not isinstance(models, (list, tuple)):
        models = [models]
    _, _, height, width = tensor.shape
    classes = None
    step = max(1, int(tile * (1 - overlap)))

    ys = list(range(0, max(1, height - tile + 1), step))
    xs = list(range(0, max(1, width - tile + 1), step))
    if ys[-1] + tile < height:
        ys.append(max(0, height - tile))
    if xs[-1] + tile < width:
        xs.append(max(0, width - tile))

    accumulated: torch.Tensor | None = None
    weights: torch.Tensor | None = None
    kernel_cache: dict[tuple[int, int], torch.Tensor] = {}

    for y in ys:
        for x in xs:
            window = tensor[:, :, y:y + tile, x:x + tile]
            window_h, window_w = window.shape[-2], window.shape[-1]
            if window_h < 32 or window_w < 32:
                continue
            probabilities = predict_probabilities(models, window, device, tta=tta)
            if accumulated is None:
                classes = probabilities.shape[0]
                accumulated = torch.zeros((classes, height, width))
                weights = torch.zeros((1, height, width))
            key = (window_h, window_w)
            if key not in kernel_cache:
                kernel = gaussian_window(max(window_h, window_w))
                kernel_cache[key] = kernel[:, :window_h, :window_w]
            kernel = kernel_cache[key]
            accumulated[:, y:y + window_h, x:x + window_w] += probabilities * kernel
            weights[:, y:y + window_h, x:x + window_w] += kernel

    if accumulated is None:
        raise ValueError(f"image {height}x{width} is smaller than any window")
    return accumulated / weights.clamp(min=1e-8)
