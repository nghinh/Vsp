#!/usr/bin/env python3
"""Generates the launcher icons for both platforms from the brand artwork.

The app shipped the stock Flutter logo — byte-identical to the SDK template —
on every density and every iOS size. This script replaces them from
docs/mockup/screen.png.

Two decisions worth knowing, because both are visible in the result:

1.  **The wordmark is dropped.** The source is a lock-up: the mark on top, then
    "VIETNAM SMART GOLF" underneath. At an mdpi launcher size the whole image is
    48x48 dp, which would render that text about 2 px tall — an orange smear
    that reads as a rendering fault. Launcher icons are marks, not lock-ups, so
    only the mark is used. The name is already under the icon on the home
    screen, from `app_name`.

2.  **Two paddings, not one.** A legacy square icon is drawn edge to edge, so
    the mark gets a modest margin. An adaptive icon's outer 25% on each side is
    cropped away by whatever mask the launcher applies (circle, squircle,
    teardrop), so its foreground gets a much wider margin to keep the mark
    inside the safe zone. Using one padding for both would either float the
    legacy icon in space or clip the adaptive one.

Run from apps/mobile:

    python3 tool/generate_icons.py

Requires Pillow. It is not a project dependency — this is a one-off asset step,
not part of the build.
"""

from __future__ import annotations

import json
import pathlib
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover - developer tooling
    sys.exit("Pillow is required: python3 -m venv .venv && .venv/bin/pip install Pillow")

MOBILE = pathlib.Path(__file__).resolve().parent.parent
SOURCE = MOBILE.parent.parent / "docs" / "mockup" / "screen.png"

# Bounding box of the mark alone, measured from the source: the artwork has two
# bands of ink, the mark at y 260-633 and the wordmark at y 682-733.
MARK_BOX = (331, 260, 693, 634)

# Sampled from the artwork's own background rather than assumed, so the icon
# and the artwork sit on the same colour.
BACKGROUND = (25, 30, 33)

# Fraction of the canvas the mark's longest side occupies.
LEGACY_SCALE = 0.68
# Adaptive foreground: the launcher mask keeps the middle 66/108 = 0.611 of the
# canvas. 0.52 fills that safe zone properly while still clearing a circular
# mask — 0.44 was inside the rules but left the mark floating in the middle of
# a large disc.
ADAPTIVE_SCALE = 0.52

ANDROID_LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive icons are authored on a 108 dp canvas.
ANDROID_ADAPTIVE = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

# filename -> pixel size. Matches the Contents.json the Flutter template ships.
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def load_mark() -> Image.Image:
    """The mark on its own, trimmed to its ink, with transparency."""
    art = Image.open(SOURCE).convert("RGB")
    mark = art.crop(MARK_BOX)

    # Knock the flat background out to alpha so the mark can be composited onto
    # a transparent adaptive foreground as well as onto a solid square.
    mark = mark.convert("RGBA")
    pixels = mark.load()
    width, height = mark.size
    br, bg_, bb = BACKGROUND
    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            # Distance from the artwork background, normalised. The mark is a
            # saturated orange, so anything near the background colour goes.
            distance = abs(r - br) + abs(g - bg_) + abs(b - bb)
            if distance < 40:
                pixels[x, y] = (r, g, b, 0)
            elif distance < 110:
                # Feather the antialiased edge instead of hard-cutting it, which
                # would leave a dark fringe when scaled down.
                pixels[x, y] = (r, g, b, int(255 * (distance - 40) / 70))
    return mark


def compose(mark: Image.Image, size: int, scale: float, background) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background)
    target = max(1, int(size * scale))
    ratio = target / max(mark.size)
    scaled = mark.resize(
        (max(1, round(mark.width * ratio)), max(1, round(mark.height * ratio))),
        Image.LANCZOS,
    )
    canvas.alpha_composite(
        scaled,
        ((size - scaled.width) // 2, (size - scaled.height) // 2),
    )
    return canvas


def write(image: Image.Image, path: pathlib.Path, *, alpha: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if alpha:
        image.save(path, "PNG")
    else:
        # App Store submission rejects an icon with an alpha channel
        # (ITMS-90717), so the iOS set is flattened onto the brand background.
        flat = Image.new("RGB", image.size, BACKGROUND)
        flat.paste(image, mask=image.split()[3])
        flat.save(path, "PNG")


def main() -> None:
    if not SOURCE.exists():
        sys.exit(f"artwork not found: {SOURCE}")

    mark = load_mark()
    res = MOBILE / "android" / "app" / "src" / "main" / "res"
    written = 0

    for folder, size in ANDROID_LEGACY.items():
        icon = compose(mark, size, LEGACY_SCALE, (*BACKGROUND, 255))
        write(icon, res / folder / "ic_launcher.png", alpha=True)
        written += 1

    for folder, size in ANDROID_ADAPTIVE.items():
        # Transparent: the background layer is a colour resource, so the
        # launcher can parallax the two against each other.
        foreground = compose(mark, size, ADAPTIVE_SCALE, (0, 0, 0, 0))
        write(foreground, res / folder / "ic_launcher_foreground.png", alpha=True)
        written += 1

    appicon = (
        MOBILE / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    )
    for name, size in IOS_ICONS.items():
        icon = compose(mark, size, LEGACY_SCALE, (*BACKGROUND, 255))
        write(icon, appicon / name, alpha=False)
        written += 1

    contents = appicon / "Contents.json"
    if contents.exists():
        # The template omits the 20x20@1x and 40x40@1x iPad entries that this
        # script writes files for; an unreferenced file in an asset catalog is
        # a build warning.
        data = json.loads(contents.read_text())
        referenced = {i.get("filename") for i in data.get("images", [])}
        orphans = sorted(set(IOS_ICONS) - referenced)
        if orphans:
            print(f"note: not referenced by Contents.json: {', '.join(orphans)}")

    print(f"wrote {written} icons from {SOURCE.name}")


if __name__ == "__main__":
    main()
