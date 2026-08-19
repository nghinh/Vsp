"""§55 — the seam between the Java backend and the vision stack.

The backend is Spring Boot and the models are PyTorch, so they do not share a
process. This is the whole of the contract between them: one call in with a
hole's coordinates, GeoJSON out, and every heavy thing — tiles, weights, GIS —
stays on this side of it.

What it deliberately does not do is decide anything. It returns geometry with
its provenance and its confidence attached; whether that geometry is good
enough to show a golfer is the backend's rule, applied in the same place it is
already applied to OpenStreetMap and to a human's survey.

    uvicorn service.app:app --host 0.0.0.0 --port 8100
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import numpy as np                                              # noqa: E402
from fastapi import Depends, FastAPI, Header, HTTPException     # noqa: E402
from pydantic import BaseModel, Field                           # noqa: E402

from golfvision.classes import APP_LAYER_TYPE, GOLF_SEG_LABELS  # noqa: E402
from golfvision.geo import webmercator as wm                    # noqa: E402
from golfvision.imagery.fetcher import (                        # noqa: E402
    TileFetcher, at_training_scale,
)
from golfvision.masks.postprocess import MaskPostProcessor      # noqa: E402
from golfvision.vector.vectorize import (                       # noqa: E402
    MaskVectorizationService, feature_collection)

app = FastAPI(title="VSP Golf Vision", version="0.1")


def require_key(authorization: str = Header(default="")) -> None:
    """A shared secret, because this listens on a public address.

    The backend that calls it is on a private network and this box is not, so
    the two can only meet out here. A segmentation service left open is a GPU
    anybody can spend and a tile fetcher anybody can point at anything, so it
    asks for a key.

    Unset means unset, not open: without GOLF_VISION_API_KEY the service
    refuses every request rather than silently serving the internet. The health
    check stays open so a load balancer can see it without holding a secret.
    """
    expected = os.environ.get("GOLF_VISION_API_KEY", "")
    if not expected:
        raise HTTPException(503, "GOLF_VISION_API_KEY is not configured")
    presented = authorization.removeprefix("Bearer ").strip()
    # Constant-time: a timing oracle on a shared secret is a small hole that
    # costs nothing to close.
    import hmac
    if not hmac.compare_digest(presented, expected):
        raise HTTPException(401, "invalid or missing API key")

#: Loaded once per process, not per request (§54). A 14 MB checkpoint costs
#: half a second to read and the GPU nothing to keep.
_model = None
_model_meta: dict = {}


class TraceRequest(BaseModel):
    course_id: int = Field(..., alias="courseId")
    hole_number: int = Field(..., alias="holeNumber")
    tee_lat: float = Field(..., alias="teeLat")
    tee_lng: float = Field(..., alias="teeLng")
    green_lat: float = Field(..., alias="greenLat")
    green_lng: float = Field(..., alias="greenLng")
    zoom: int = 19
    margin_deg: float = Field(0.0010, alias="marginDeg")

    class Config:
        populate_by_name = True


def _load():
    """The trained GolfSeg — one weight or an ensemble — or a clear refusal.

    §4 and §52: an unavailable model is a 503 with a reason, never a crash and
    never a silently empty answer that reads as "this hole has no bunkers".

    GOLF_SEG_CHECKPOINT takes one path, or several separated by colons; every
    member answers every window and their probabilities are averaged
    (golfvision.inference). Members may differ in input width. The metadata
    reported on /health is the first member's — the primary — with the others
    listed beside it, and the lineage union of all of them, because "may we
    sell what this produces" is a question about every weight that voted.
    """
    global _model, _model_meta
    if _model is not None:
        return _model

    import torch
    from training.models import build_model

    setting = os.environ.get("GOLF_SEG_CHECKPOINT", "")
    paths = [p for p in setting.split(":") if p]
    missing = [p for p in paths if not Path(p).exists()]
    if not paths or missing:
        raise HTTPException(503, "GOLF_SEG_CHECKPOINT is not set or missing"
                            + (f": {', '.join(missing)}" if missing else ""))

    device = torch.device(os.environ.get("GOLF_VISION_DEVICE")
                          or ("cuda" if torch.cuda.is_available() else "cpu"))
    models, states = [], []
    for path in paths:
        state = torch.load(path, map_location="cpu", weights_only=False)
        # How many channels this weight expects, read rather than assumed.
        # The NAIP corpus made four the default — three colour bands and a
        # near-infrared one that Esri tiles cannot supply — and a checkpoint
        # from before that is still three. Guessing wrong fails at load with
        # a shape error that reads like a corrupt file.
        model = build_model(len(GOLF_SEG_LABELS),
                            provider=state["args"].get("provider", "smp"),
                            name=state["args"].get("model_name"),
                            in_channels=state.get("inChannels", 3))
        model.load_state_dict(state["model"])
        model.eval().to(device)
        models.append(model)
        states.append(state)

    state = states[0]
    lineage = [step for s in states for step in s.get("lineage", [])]
    shippable = [s.get("shippable") for s in states]

    _model = models
    _model_meta = {
        "checkpoint": Path(paths[0]).name,
        "ensemble": [Path(p).name for p in paths] if len(paths) > 1 else None,
        "device": str(device),
        "provider": state["args"].get("provider"),
        "modelName": state["args"].get("model_name"),
        "inChannels": max(m.in_channels for m in models),
        "trainedEpoch": state.get("epoch"),
        "commercialOk": all(m.commercial_ok for m in models),
        # Which corpora these weights have seen and whether their imagery
        # licences permit selling the result. On /health because "which model
        # is live" and "may we sell what it produces" have to be answerable
        # from outside the process, months later, without reading a filename.
        "lineage": lineage,
        # An ensemble ships only if every member may: one research-only
        # weight in the average poisons the answer exactly as it would alone.
        "shippable": (None if any(s is None for s in shippable)
                      else all(shippable)),
        "scores": state.get("scores", {}),
    }
    return _model


@app.get("/health")
def health():
    ready = bool(os.environ.get("GOLF_SEG_CHECKPOINT"))
    return {"status": "ok", "modelConfigured": ready, "model": _model_meta}


@app.post("/trace/hole", dependencies=[Depends(require_key)])
def trace_hole(request: TraceRequest):
    """One hole, traced. GeoJSON in WGS84, with provenance on every feature."""
    import torch

    model = _load()
    fetcher = TileFetcher()

    south = min(request.tee_lat, request.green_lat) - request.margin_deg
    north = max(request.tee_lat, request.green_lat) + request.margin_deg
    west = min(request.tee_lng, request.green_lng) - request.margin_deg
    east = max(request.tee_lng, request.green_lng) + request.margin_deg

    started = time.time()
    try:
        # The finest zoom that is actually a photograph, then resampled to the
        # scale the model was trained at.
        #
        # Both halves earn their place. Esri answers a request outside its
        # high-resolution coverage with a flat placeholder rather than a 404 —
        # over Bắc Giang at zoom 19 that is 123 colours across 400 000 pixels,
        # and two samples three kilometres apart come back byte-identical. The
        # model, shown a blank, returned 116 shapes at 0.22 confidence, which
        # the API's confidence floor then discarded: a course reported as
        # having no features, when what it had was no imagery. Zoom 18 over the
        # same ground is a real picture at 0.56 m.
        tile = at_training_scale(
            fetcher.fetch_best(south, west, north, east, zoom=request.zoom,
                               max_pixels=100_000))
    except Exception as error:                    # noqa: BLE001
        raise HTTPException(502, f"imagery unavailable: {error}") from error

    pixels = torch.from_numpy(
        (tile.pixels.astype(np.float32) / 255.0
         - np.array([0.485, 0.456, 0.406], dtype=np.float32))
        / np.array([0.229, 0.224, 0.225], dtype=np.float32)
    ).permute(2, 0, 1).unsqueeze(0)

    # The fourth channel, where the model wants one. Esri serves three bands
    # and there is no near-infrared to be had from a tile server, so it is the
    # same constant the training set used for a missing band — and the model
    # spent half of its pretraining with that band hidden precisely so this
    # would be ordinary rather than out of distribution.
    if _model_meta.get("inChannels", 3) == 4:
        # Imported here rather than at module scope: training.dataset pulls in
        # torch, and this service loads torch lazily so a process with no
        # model configured still answers /health immediately. Imported at all
        # rather than written as 0.0, so the service and the training set
        # cannot drift on what "no band" means.
        from training.dataset import NIR_ABSENT
        absent = torch.full((1, 1, pixels.shape[2], pixels.shape[3]),
                            NIR_ABSENT, dtype=pixels.dtype)
        pixels = torch.cat([pixels, absent], dim=1)

    # TTA and Gaussian blending, exactly as the evaluation harness scores
    # them (golfvision.inference — one asking path for every caller). The
    # sweep runs offline on an A100, so eight views per window is time nobody
    # is waiting on; GOLF_SEG_TTA=0 turns it off for interactive use.
    from golfvision.inference import infer_tiled
    device = next(model[0].parameters()).device
    tta = os.environ.get("GOLF_SEG_TTA", "1") != "0"
    probabilities = infer_tiled(model, pixels, device, tta=tta).numpy()
    predicted = probabilities.argmax(axis=0)

    cleaner = MaskPostProcessor(tile.bounds.metres_per_pixel)
    vectorizer = MaskVectorizationService(tile.bounds)

    features = []
    for index, feature_type in GOLF_SEG_LABELS.items():
        if index == 0 or feature_type not in APP_LAYER_TYPE:
            continue
        mask = cleaner.clean(predicted == index, feature_type)
        if not mask.any():
            continue
        confidence = float(probabilities[index][mask].mean())
        for shape in vectorizer.vectorize(mask, APP_LAYER_TYPE[feature_type],
                                          simplify_m=0.4):
            shape.scores["vision"] = confidence
            shape.scores["geometry"] = 1.0
            shape.evidence["golfSegClass"] = feature_type.value
            features.append(shape)

    elapsed = time.time() - started
    return feature_collection(features, tile.attribution, {
        **tile.bounds.metadata,
        "courseId": request.course_id,
        "holeNumber": request.hole_number,
        "metresPerPixel": round(tile.bounds.metres_per_pixel, 4),
        "elapsedSeconds": round(elapsed, 2),
        "source": "golfseg",
        **_model_meta,
    })


__all__ = ["app"]
