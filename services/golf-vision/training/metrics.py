"""Per-class IoU, accumulated over a validation set.

The metric that decides which checkpoint ships. Kept per class rather than
averaged, because a mean IoU that looks respectable can hide a green at 0.1 —
and the green is the one that matters. Ignore pixels never enter the
confusion matrix, so an unmapped region neither helps nor hurts the score.
"""

from __future__ import annotations

import numpy as np
import torch

IGNORE_INDEX = 255


class ConfusionMatrix:

    def __init__(self, num_classes: int):
        self.num_classes = num_classes
        self.matrix = np.zeros((num_classes, num_classes), dtype=np.int64)

    def update(self, prediction: torch.Tensor, target: torch.Tensor) -> None:
        pred = prediction.flatten().cpu().numpy()
        true = target.flatten().cpu().numpy()
        keep = true != IGNORE_INDEX
        pred, true = pred[keep], true[keep]
        binned = np.bincount(
            self.num_classes * true + pred,
            minlength=self.num_classes ** 2)
        self.matrix += binned.reshape(self.num_classes, self.num_classes)

    def per_class_iou(self) -> np.ndarray:
        intersection = np.diag(self.matrix)
        union = self.matrix.sum(0) + self.matrix.sum(1) - intersection
        with np.errstate(divide="ignore", invalid="ignore"):
            iou = intersection / union
        return iou

    def per_class_recall(self) -> np.ndarray:
        support = self.matrix.sum(1)
        with np.errstate(divide="ignore", invalid="ignore"):
            return np.diag(self.matrix) / support

    def support(self) -> np.ndarray:
        return self.matrix.sum(1)

    def mean_iou(self) -> float:
        """Averaged over classes that actually appeared in the truth.

        A class with no ground-truth pixels in the validation set has an
        undefined IoU, and folding a NaN — or a zero — into the mean punishes
        or flatters the model for a class it was never asked about.
        """
        iou = self.per_class_iou()
        present = self.support() > 0
        values = iou[present]
        values = values[~np.isnan(values)]
        return float(values.mean()) if values.size else 0.0
