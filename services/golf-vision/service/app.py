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
from fastapi import FastAPI, HTTPException                      # noqa: E402
from pydantic import BaseModel, Field                           # noqa: E402

from golfvision.classes import APP_LAYER_TYPE, GOLF_SEG_LABELS  # noqa: E402
from golfvision.geo import webmercator as wm                    # noqa: E402
from golfvision.imagery.fetcher import TileFetcher              # noqa: E402
from golfvision.masks.postprocess import MaskPostProcessor      # noqa: E402
from golfvision.vector.vectorize import (                       # noqa: E402
    MaskVectorizationService, feature_collection)

app = FastAPI(title="VSP Golf Vision", version="0.1")

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
    """The trained GolfSeg, or a clear refusal.

    §4 and §52: an unavailable model is a 503 with a reason, never a crash and
    never a silently empty answer that reads as "this hole has no bunkers".
    """
    global _model, _model_meta
    if _model is not None:
        return _model

    import torch
    from training.models import build_model

    path = os.environ.get("GOLF_SEG_CHECKPOINT")
    if not path or not Path(path).exists():
        raise HTTPException(503, "GOLF_SEG_CHECKPOINT is not set or missing")

    state = torch.load(path, map_location="cpu", weights_only=False)
    model = build_model(len(GOLF_SEG_LABELS),
                        provider=state["args"].get("provider", "smp"),
                        name=state["args"].get("model_name"))
    model.load_state_dict(state["model"])
    device = torch.device(os.environ.get("GOLF_VISION_DEVICE")
                          or ("cuda" if torch.cuda.is_available() else "cpu"))
    model.eval().to(device)

    _model = model
    _model_meta = {
        "checkpoint": Path(path).name,
        "device": str(device),
        "provider": state["args"].get("provider"),
        "modelName": state["args"].get("model_name"),
        "trainedEpoch": state.get("epoch"),
        "commercialOk": state.get("commercialOk", False),
        "scores": state.get("scores", {}),
    }
    return _model


@app.get("/health")
def health():
    ready = bool(os.environ.get("GOLF_SEG_CHECKPOINT"))
    return {"status": "ok", "modelConfigured": ready, "model": _model_meta}


@app.post("/trace/hole")
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
        tile = fetcher.fetch(south, west, north, east, zoom=request.zoom,
                             max_pixels=100_000)
    except Exception as error:                    # noqa: BLE001
        raise HTTPException(502, f"imagery unavailable: {error}") from error

    pixels = torch.from_numpy(
        (tile.pixels.astype(np.float32) / 255.0
         - np.array([0.485, 0.456, 0.406], dtype=np.float32))
        / np.array([0.229, 0.224, 0.225], dtype=np.float32)
    ).permute(2, 0, 1).unsqueeze(0)

    device = next(model.parameters()).device
    with torch.no_grad():
        logits = _infer_tiled(model, pixels, device)
        probabilities = torch.softmax(logits, dim=0).cpu().numpy()
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


def _infer_tiled(model, tensor, device, tile: int = 512, overlap: float = 0.25):
    """Overlapping windows, averaged — §8, so no seam runs down a fairway."""
    import torch
    _, _, height, width = tensor.shape
    classes = len(GOLF_SEG_LABELS)
    step = max(1, int(tile * (1 - overlap)))
    accumulated = torch.zeros((classes, height, width), dtype=torch.float32)
    weights = torch.zeros((1, height, width), dtype=torch.float32)

    ys = list(range(0, max(1, height - tile + 1), step))
    xs = list(range(0, max(1, width - tile + 1), step))
    if ys[-1] + tile < height:
        ys.append(height - tile)
    if xs[-1] + tile < width:
        xs.append(width - tile)

    for y in ys:
        for x in xs:
            window = tensor[:, :, y:y + tile, x:x + tile]
            if window.shape[-1] < 32 or window.shape[-2] < 32:
                continue
            out = model(window.to(device))[0].float().cpu()
            accumulated[:, y:y + out.shape[1], x:x + out.shape[2]] += out
            weights[:, y:y + out.shape[1], x:x + out.shape[2]] += 1

    return accumulated / weights.clamp(min=1)


__all__ = ["app"]
