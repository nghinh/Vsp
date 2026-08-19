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


class LovaszSoftmaxLoss(nn.Module):
    """The Lovász extension of the IoU loss (Berman et al., CVPR 2018).

    Dice approximates overlap; this optimises the IoU surrogate directly, by
    sorting each class's prediction errors and weighting them with the
    gradient of the Jaccard set function. In practice it moves exactly the
    metric this project reports, and it is strongest late in training when
    cross-entropy has plateaued — which is why it arrives as an extra term
    with its own weight rather than a replacement.

    Ignore-aware the same way everything here is: an unmapped bunker costs
    nothing.
    """

    def forward(self, logits: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
        probabilities = F.softmax(logits, dim=1)
        batch, classes, _, _ = probabilities.shape
        flat = probabilities.permute(0, 2, 3, 1).reshape(-1, classes)
        labels = target.reshape(-1)
        valid = labels != IGNORE_INDEX
        if not valid.any():
            return logits.sum() * 0.0
        flat, labels = flat[valid], labels[valid]

        losses = []
        for index in range(classes):
            foreground = (labels == index).float()
            if foreground.sum() == 0:
                continue   # absent classes are the metric's business, not ours
            errors = (foreground - flat[:, index]).abs()
            errors_sorted, order = torch.sort(errors, descending=True)
            sorted_foreground = foreground[order]

            intersection = sorted_foreground.sum() - sorted_foreground.cumsum(0)
            union = sorted_foreground.sum() + (1 - sorted_foreground).cumsum(0)
            jaccard = 1.0 - intersection / union
            if jaccard.numel() > 1:
                jaccard[1:] = jaccard[1:] - jaccard[:-1]
            losses.append((errors_sorted * jaccard).sum())
        if not losses:
            return logits.sum() * 0.0
        return torch.stack(losses).mean()


class GolfSegLoss(nn.Module):
    """Weighted cross-entropy plus a Dice term, with Lovász available.

    The mix (``dice_weight``) is a knob, not a truth. Cross-entropy alone
    gives sharp boundaries and ignores the rare classes; Dice alone chases
    overlap and produces blobby edges. For a rangefinder the boundary is what
    a golfer feels, so cross-entropy leads and Dice supports. Lovász, off by
    default, optimises the reported IoU directly and earns its keep late in
    training; it is compared against the default across seeds rather than
    assumed better.
    """

    def __init__(self, num_classes: int, class_weights: torch.Tensor | None = None,
                 dice_weight: float = 0.5, lovasz_weight: float = 0.0):
        super().__init__()
        self.cross_entropy = nn.CrossEntropyLoss(
            weight=class_weights, ignore_index=IGNORE_INDEX)
        self.dice = DiceLoss(num_classes)
        self.lovasz = LovaszSoftmaxLoss()
        self.dice_weight = dice_weight
        self.lovasz_weight = lovasz_weight

    def forward(self, logits: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
        loss = self.cross_entropy(logits, target)
        if self.dice_weight:
            loss = loss + self.dice_weight * self.dice(logits, target)
        if self.lovasz_weight:
            loss = loss + self.lovasz_weight * self.lovasz(logits, target)
        return loss
