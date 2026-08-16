"""The two vocabularies, kept apart on purpose.

Level 1 is what a remote-sensing model can see: grass is grass whether it is
mown to eight millimetres or left to grow. Level 2 is what golf calls those
things, and the difference between a green and a fairway is not visual at all
— it is where they sit relative to each other and how they are used.

Conflating the two is what makes a model confidently label a car park a
bunker. A land-cover model that says "bare ground, 0.94" is right; the golf
layer is where that becomes a bunker or does not.
"""

from __future__ import annotations

from enum import Enum


class LandCover(str, Enum):
    """Level 1 — generic, and directly observable."""

    GRASS = "grass"
    TREE = "tree"
    FOREST = "forest"
    WATER = "water"
    ROAD = "road"
    PAVEMENT = "pavement"
    BUILDING = "building"
    BARE_LAND = "bare_land"
    SAND = "sand"
    VEGETATION = "vegetation"
    UNKNOWN = "unknown"


class GolfFeature(str, Enum):
    """Level 2 — golf, and mostly inferred from position rather than colour."""

    BACKGROUND = "background"
    TEE_BOX = "tee_box"
    FAIRWAY = "fairway"
    GREEN = "green"
    BUNKER = "bunker"
    ROUGH = "rough"
    WATER_HAZARD = "water_hazard"
    CART_PATH = "cart_path"
    PRACTICE_GREEN = "practice_green"
    DRIVING_RANGE = "driving_range"
    TREE = "tree"


#: The training label indices from §36, fixed so a dataset written today is
#: still readable by a model trained next year.
GOLF_SEG_LABELS: dict[int, GolfFeature] = {
    0: GolfFeature.BACKGROUND,
    1: GolfFeature.TEE_BOX,
    2: GolfFeature.FAIRWAY,
    3: GolfFeature.GREEN,
    4: GolfFeature.BUNKER,
    5: GolfFeature.ROUGH,
    6: GolfFeature.WATER_HAZARD,
    7: GolfFeature.CART_PATH,
    8: GolfFeature.TREE,
}


#: How Level 2 maps onto the layers the app and the database already use.
#: Existing manually digitised courses keep working because nothing here
#: renames what they are stored as.
APP_LAYER_TYPE: dict[GolfFeature, str] = {
    GolfFeature.TEE_BOX: "TEE",
    GolfFeature.FAIRWAY: "FAIRWAY",
    GolfFeature.GREEN: "GREEN",
    GolfFeature.BUNKER: "BUNKER",
    GolfFeature.ROUGH: "ROUGH",
    GolfFeature.WATER_HAZARD: "WATER_HAZARD",
    GolfFeature.CART_PATH: "CART_PATH",
    GolfFeature.TREE: "LANDMARK",
}
