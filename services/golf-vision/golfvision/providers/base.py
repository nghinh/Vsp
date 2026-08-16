"""What a model has to offer to be usable here.

Three interfaces, because the pipeline asks three different questions and the
answers come from different kinds of model:

  * a land-cover model says what the ground is made of;
  * a golf model — when one exists — says what golf calls it;
  * a refiner says where the edge actually runs.

Nothing here returns coordinates. Every provider works in pixels, and pixels
become degrees in exactly one place. That is the whole point of the refactor:
a model that never sees a latitude cannot invent one.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any

import numpy as np

from ..classes import GolfFeature, LandCover


@dataclass
class ClassMask:
    """One class, and where it is.

    ``mask`` is a boolean array the size of the image. It stays server-side —
    §6 — because a 2048² boolean per class per tile is not something to send
    to a phone, and the phone has no use for it: it wants the polygon.
    """

    label: str
    mask: np.ndarray
    confidence: float

    #: Mean per-pixel probability inside the mask, where the model gives one.
    #: Distinct from ``confidence``, which may be a whole-region score.
    mean_probability: float | None = None

    @property
    def pixel_count(self) -> int:
        return int(self.mask.sum())


@dataclass
class SegmentationResult:
    width: int
    height: int
    classes: list[ClassMask] = field(default_factory=list)

    #: Everything §39 wants recorded so a detection can be regenerated when a
    #: better model arrives.
    model_name: str = ""
    model_version: str = ""
    model_checkpoint: str = ""
    pipeline_version: str = ""
    dataset_version: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def by_label(self, label: str) -> ClassMask | None:
        for entry in self.classes:
            if entry.label == label:
                return entry
        return None


class LandCoverSegmentationProvider(ABC):
    """Level 1. Generic classes, from a remote-sensing model."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def available(self) -> bool:
        """False rather than raising: §4 says the app boots without a model."""

    @abstractmethod
    def segment(self, image: np.ndarray,
                metadata: dict[str, Any] | None = None) -> SegmentationResult:
        """Land-cover masks for one image, in :class:`LandCover` labels."""


class GolfSegmentationProvider(ABC):
    """Level 2. Golf classes — trained, or inferred from Level 1."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def available(self) -> bool: ...

    @abstractmethod
    def segment(self, image: np.ndarray, land_cover: SegmentationResult,
                metadata: dict[str, Any] | None = None) -> SegmentationResult:
        """Golf masks, in :class:`GolfFeature` labels."""


class BoundaryRefinementProvider(ABC):
    """Where the edge really runs, given a rough idea of where to look."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def available(self) -> bool: ...

    @abstractmethod
    def refine(self, image: np.ndarray, mask: np.ndarray,
               hints: dict[str, Any] | None = None) -> np.ndarray:
        """A tighter mask, or the one it was given when it cannot do better.

        Never None. A refiner that fails should hand back what it was asked to
        improve — losing a rough boundary because the refinement failed is a
        worse outcome than keeping it.
        """


__all__ = [
    "ClassMask", "SegmentationResult",
    "LandCoverSegmentationProvider", "GolfSegmentationProvider",
    "BoundaryRefinementProvider",
    "LandCover", "GolfFeature",
]
