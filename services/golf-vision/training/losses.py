"""Loss for a problem where the classes are nothing like balanced.

Measured on the first course built: water 65%, background 32%, green 2.9%,
bunker 0.3%. A plain cross-entropy on that learns to call everything water
and background and score well doing it — the green and the bunker, which are
the whole point of a rangefinder, cost it almost nothing to miss.

§42 lists the tools; this combines the two that actually address it. Class
weights lift the rare classes in the cross-entropy, and a Dice term optimises
overlap directly, which is what IoU rewards and what cross-entropy only
approximates. Both honour the ignore index, because the dataset is full of it
by design — an unmapped bunker must cost nothing rather than teach "grass".
"""

from __future__ import annotations

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

IGNORE_INDEX = 255


def median_frequency_weights(counts: np.ndarray, cap: float = 12.0) -> torch.Tensor:
    """Median-frequency balancing, capped.

    A class with a hundredth the pixels of the median gets a hundred times
    the weight, uncapped — enough to make the model hallucinate it everywhere.
    The cap keeps the rare classes loud without letting one drown the loss.
    """
    frequencies = counts / max(1, counts.sum())
    present = frequencies > 0
    median = np.median(frequencies[present]) if present.any() else 1.0
    weights = np.ones_like(frequencies, dtype=np.float32)
    weights[present] = np.minimum(median / frequencies[present], cap)
    return torch.tensor(weights, dtype=torch.float32)


class DiceLoss(nn.Module):
    """Soft Dice over the classes that appear in the batch, ignore-aware."""

    def __init__(self, num_classes: int, smooth: float = 1.0):
        super().__init__()
        self.num_classes = num_classes
        self.smooth = smooth

    def forward(self, logits: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
        probabilities = F.softmax(logits, dim=1)
        valid = target != IGNORE_INDEX
        if not valid.any():
            return logits.sum() * 0.0

        safe_target = torch.where(valid, target, torch.zeros_like(target))
        one_hot = F.one_hot(safe_target, self.num_classes).permute(0, 3, 1, 2).float()
        mask = valid.unsqueeze(1).float()
        probabilities = probabilities * mask
        one_hot = one_hot * mask

        dims = (0, 2, 3)
        intersection = (probabilities * one_hot).sum(dims)
        union = probabilities.sum(dims) + one_hot.sum(dims)
        present = one_hot.sum(dims) > 0
        if not present.any():
            return logits.sum() * 0.0
        dice = (2 * intersection + self.smooth) / (union + self.smooth)
        return 1.0 - dice[present].mean()


class GolfSegLoss(nn.Module):
    """Weighted cross-entropy plus a Dice term, the two summed.

    The mix (``dice_weight``) is a knob, not a truth. Cross-entropy alone
    gives sharp boundaries and ignores the rare classes; Dice alone chases
    overlap and produces blobby edges. For a rangefinder the boundary is what
    a golfer feels, so cross-entropy leads and Dice supports.
    """

    def __init__(self, num_classes: int, class_weights: torch.Tensor | None = None,
                 dice_weight: float = 0.5):
        super().__init__()
        self.cross_entropy = nn.CrossEntropyLoss(
            weight=class_weights, ignore_index=IGNORE_INDEX)
        self.dice = DiceLoss(num_classes)
        self.dice_weight = dice_weight

    def forward(self, logits: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
        return (self.cross_entropy(logits, target)
                + self.dice_weight * self.dice(logits, target))
