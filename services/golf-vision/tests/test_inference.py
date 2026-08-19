"""The inference module has one property everything rests on: every view it
shows the model is undone exactly before averaging. A TTA that mis-inverts one
of the eight symmetries does not crash — it blurs every prediction toward its
own mistake, scores a little worse than no TTA at all, and reads like a model
problem. So the tests here are about invariants, not numbers.
"""

from __future__ import annotations

import sys
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.inference import (  # noqa: E402
    _DIHEDRAL, _apply, _undo, gaussian_window, infer_tiled,
    predict_probabilities)


class Echo(torch.nn.Module):
    """Returns its input as logits — an exactly equivariant "model".

    For a function that commutes with every dihedral transform, TTA must be a
    no-op: transform, apply, inverse-transform lands each view back on the
    original. Any error in the inverse shows up as a mismatch here.
    """

    def forward(self, pixels):
        return pixels


class Fixed(torch.nn.Module):
    """Ignores its input — a maximally non-equivariant "model".

    Its TTA average is the average of the eight inverse transforms of one
    constant pattern, which the test computes independently.
    """

    def __init__(self, pattern):
        super().__init__()
        self.pattern = pattern

    def forward(self, pixels):
        return self.pattern.unsqueeze(0).expand(pixels.shape[0], -1, -1, -1)


def test_every_view_is_undone_exactly():
    pixels = torch.randn(1, 3, 16, 16)
    for quarter_turns, flip in _DIHEDRAL:
        undone = _undo(_apply(pixels, quarter_turns, flip), quarter_turns, flip)
        assert torch.equal(undone, pixels), (quarter_turns, flip)


def test_tta_of_an_equivariant_model_is_a_no_op():
    pixels = torch.rand(1, 3, 32, 32)
    direct = predict_probabilities(Echo(), pixels, "cpu", tta=False)
    averaged = predict_probabilities(Echo(), pixels, "cpu", tta=True)
    assert torch.allclose(direct, averaged, atol=1e-6)


def test_tta_averages_what_the_model_actually_said():
    pattern = torch.randn(3, 8, 8)
    result = predict_probabilities(Fixed(pattern), torch.rand(1, 3, 8, 8),
                                   "cpu", tta=True)
    expected = torch.zeros(3, 8, 8)
    for quarter_turns, flip in _DIHEDRAL:
        expected += _undo(torch.softmax(pattern, dim=0), quarter_turns, flip)
    assert torch.allclose(result, expected / len(_DIHEDRAL), atol=1e-6)


def test_probabilities_sum_to_one():
    result = predict_probabilities(Fixed(torch.randn(5, 8, 8)),
                                   torch.rand(1, 3, 8, 8), "cpu", tta=True)
    assert torch.allclose(result.sum(dim=0), torch.ones(8, 8), atol=1e-5)


def test_ensemble_members_see_the_channels_they_expect():
    class Wants(torch.nn.Module):
        def __init__(self, channels):
            super().__init__()
            self.in_channels = channels
            self.saw = None

        def forward(self, pixels):
            self.saw = pixels.shape[1]
            return pixels[:, :1].expand(-1, 4, -1, -1)

    three, four = Wants(3), Wants(4)
    predict_probabilities([three, four], torch.rand(1, 4, 8, 8), "cpu",
                          tta=False)
    assert three.saw == 3
    assert four.saw == 4


def test_gaussian_window_prefers_the_centre():
    kernel = gaussian_window(64)[0]
    assert kernel[32, 32] > kernel[0, 0] * 10
    assert kernel.max() <= 1.0
    assert (kernel > 0).all(), "an edge vote is a whisper, never zero"


def test_tiled_probabilities_cover_the_image_and_sum_to_one():
    # An image larger than one window, forcing overlap and edge windows.
    result = infer_tiled(Echo(), torch.rand(1, 4, 80, 112), "cpu",
                         tile=64, overlap=0.25, tta=False)
    assert result.shape == (4, 80, 112)
    assert torch.allclose(result.sum(dim=0), torch.ones(80, 112), atol=1e-4)


def test_tiled_blending_is_seamless_for_a_constant_answer():
    # A model that always answers the same thing must produce exactly that
    # answer everywhere, whatever the window layout — any deviation is the
    # blending arithmetic leaking.
    pattern = torch.randn(3, 64, 64)

    class Constant(torch.nn.Module):
        def forward(self, pixels):
            h, w = pixels.shape[-2:]
            return torch.softmax(pattern[:, :h, :w], dim=0).log().unsqueeze(0)

    result = infer_tiled(Constant(), torch.rand(1, 3, 64, 64), "cpu",
                         tile=64, overlap=0.25, tta=False)
    assert torch.allclose(result, torch.softmax(pattern, dim=0), atol=1e-5)
