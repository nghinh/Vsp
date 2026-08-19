"""The Lovász term is easy to transcribe wrongly and hard to notice: a sign
slip or an unsorted cumsum still converges, just worse, and reads as "Lovász
did not help". These tests pin the properties the derivation guarantees.
"""

from __future__ import annotations

import sys
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from training.losses import (  # noqa: E402
    GolfSegLoss, LovaszSoftmaxLoss, IGNORE_INDEX)


def logits_for(target: torch.Tensor, classes: int, right: float) -> torch.Tensor:
    """Logits that are correct with confidence `right` everywhere."""
    wrong = (1 - right) / (classes - 1)
    probabilities = torch.full((1, classes) + target.shape[-2:], wrong)
    for index in range(classes):
        probabilities[0, index][target[0] == index] = right
    return probabilities.clamp(1e-6, 1).log()


def test_perfect_prediction_costs_nearly_nothing():
    target = torch.randint(0, 4, (1, 16, 16))
    loss = LovaszSoftmaxLoss()(logits_for(target, 4, 0.999), target)
    assert loss.item() < 0.01


def test_worse_overlap_costs_more():
    target = torch.zeros(1, 16, 16, dtype=torch.long)
    target[0, :, 8:] = 1
    good = LovaszSoftmaxLoss()(logits_for(target, 2, 0.9), target)

    # The same shape shifted: half of class 1 called class 0.
    shifted = target.clone()
    shifted[0, :, 8:12] = 0
    bad = LovaszSoftmaxLoss()(logits_for(shifted, 2, 0.9), target)
    assert bad.item() > good.item()


def test_ignored_pixels_cost_nothing():
    target = torch.zeros(1, 8, 8, dtype=torch.long)
    target[0, :4] = 1
    with_ignore = target.clone()
    with_ignore[0, 6:] = IGNORE_INDEX

    # Logits that are wrong exactly where the ignore is: same loss either way
    # once those pixels are ignored, different if they are not.
    logits = logits_for(target, 2, 0.9)
    logits[0, :, 6:, :] = torch.tensor([0.1, 10.0])[:, None, None]

    clean = LovaszSoftmaxLoss()(logits_for(target, 2, 0.9)[:, :, :6, :],
                                target[:, :6, :])
    ignored = LovaszSoftmaxLoss()(logits, with_ignore)
    assert abs(clean.item() - ignored.item()) < 1e-5


def test_all_ignore_is_zero_and_differentiable():
    target = torch.full((1, 8, 8), IGNORE_INDEX, dtype=torch.long)
    logits = torch.randn(1, 3, 8, 8, requires_grad=True)
    loss = LovaszSoftmaxLoss()(logits, target)
    loss.backward()
    assert loss.item() == 0.0
    assert logits.grad is not None


def test_the_combined_loss_only_pays_for_terms_it_ordered():
    target = torch.randint(0, 3, (1, 16, 16))
    logits = torch.randn(1, 3, 16, 16)
    plain = GolfSegLoss(3, dice_weight=0.5, lovasz_weight=0.0)
    with_lovasz = GolfSegLoss(3, dice_weight=0.5, lovasz_weight=0.5)
    assert with_lovasz(logits, target).item() != plain(logits, target).item()
    # And the default is bit-identical to what every earlier run trained with.
    default = GolfSegLoss(3, dice_weight=0.5)
    assert default(logits, target).item() == plain(logits, target).item()
