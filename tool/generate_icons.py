#!/usr/bin/env python3
"""Generate the Songs of the Church app icon for every platform.

The artwork lives in ICON_TEMPLATE below and is the single source of truth.
Running this script rewrites tool/app_icon.svg (a viewable reference copy) and
every raster icon under android/, ios/, macos/, web/ and windows/.

Usage:  python3 tool/generate_icons.py
Needs:  pip install Pillow cairosvg
"""

from __future__ import annotations

import io
import json
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

# Brand navy, matching AppPalette.navy in lib/theme.dart.
NAVY = "#1C3975"

# The note's own bounding box is centred on this point, so scaling about the
# canvas centre keeps it centred while each variant gets its own breathing room.
NOTE_CX, NOTE_CY = 503, 430

FULL_BLEED_SCALE = 1.65   # app icon: note stands ~61% of the canvas tall
MASKABLE_SCALE = 1.50     # web maskable: survives an 80%-diameter circle
ADAPTIVE_SCALE = 1.30     # android adaptive: survives the 66dp safe circle

ICON_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
{background}
  <!-- eighth note, scaled about its own centre and placed on the canvas centre -->
  <g fill="#FFFFFF"
     transform="translate(512,512) scale({scale}) translate({-cx},{-cy})">
    <rect x="484" y="242" width="30" height="312" rx="15"/>
    <!-- the flag starts inside the stem so the two shapes overlap; abutting
         them exactly leaves an anti-aliasing seam down the stem -->
    <path d="M496 250
             C 596 284, 654 338, 654 410
             C 654 454, 631 488, 601 509
             C 616 473, 611 431, 582 400
             C 559 375, 530 356, 496 342
             Z"/>
    <ellipse cx="436" cy="552" rx="86" ry="64" transform="rotate(-20 436 552)"/>
  </g>
</svg>
"""

SOLID_BACKGROUND = f'\n  <rect width="1024" height="1024" fill="{NAVY}"/>\n'


def build_svg(scale: float, *, background: bool) -> str:
    return ICON_TEMPLATE.format(
        scale=scale,
        background=SOLID_BACKGROUND if background else "",
        **{"-cx": -NOTE_CX, "-cy": -NOTE_CY},
    )


def render(svg: str, size: int) -> Image.Image:
    png = cairosvg.svg2png(
        bytestring=svg.encode(), output_width=size, output_height=size
    )
    return Image.open(io.BytesIO(png)).convert("RGBA")


def save(image: Image.Image, path: Path, *, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if opaque:
        # App Store rejects icons with an alpha channel.
        flat = Image.new("RGB", image.size, NAVY)
        flat.paste(image, mask=image.split()[3])
        flat.save(path)
    else:
        image.save(path)
    print(f"  {path.relative_to(ROOT)}")


def main() -> None:
    full = build_svg(FULL_BLEED_SCALE, background=True)
    maskable = build_svg(MASKABLE_SCALE, background=True)
    adaptive = build_svg(ADAPTIVE_SCALE, background=False)

    print("source svg")
    (ROOT / "tool" / "app_icon.svg").write_text(full)
    print("  tool/app_icon.svg")

    print("ios")
    for name, size in {
        "Icon-App-20x20@1x": 20, "Icon-App-20x20@2x": 40, "Icon-App-20x20@3x": 60,
        "Icon-App-29x29@1x": 29, "Icon-App-29x29@2x": 58, "Icon-App-29x29@3x": 87,
        "Icon-App-40x40@1x": 40, "Icon-App-40x40@2x": 80, "Icon-App-40x40@3x": 120,
        "Icon-App-60x60@2x": 120, "Icon-App-60x60@3x": 180,
        "Icon-App-76x76@1x": 76, "Icon-App-76x76@2x": 152,
        "Icon-App-83.5x83.5@2x": 167,
        "Icon-App-1024x1024@1x": 1024,
    }.items():
        save(
            render(full, size),
            ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset" / f"{name}.png",
            opaque=True,
        )

    print("macos")
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save(
            render(full, size),
            ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset" / f"app_icon_{size}.png",
            opaque=True,
        )

    print("android")
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for density, factor in densities.items():
        res = ROOT / "android/app/src/main/res" / f"mipmap-{density}"
        # Legacy launcher icon (pre-Android 8) and the adaptive foreground layer.
        save(render(full, round(48 * factor)), res / "ic_launcher.png")
        save(render(adaptive, round(108 * factor)), res / "ic_launcher_foreground.png")

    print("web")
    save(render(full, 16), ROOT / "web/favicon.png")
    for size in (192, 512):
        save(render(full, size), ROOT / "web/icons" / f"Icon-{size}.png")
        save(render(maskable, size), ROOT / "web/icons" / f"Icon-maskable-{size}.png")

    print("windows")
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    sizes = [16, 32, 48, 64, 128, 256]
    render(full, 256).save(ico, sizes=[(s, s) for s in sizes])
    print(f"  {ico.relative_to(ROOT)}")

    print("linux")
    # Used by the .desktop entry and as the AppImage's icon.
    save(render(full, 256), ROOT / "linux/packaging/songs-of-the-church.png")

    # Keep the iOS asset catalog honest about the alpha-free icons above.
    contents = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    data = json.loads(contents.read_text())
    assert all("filename" in i for i in data["images"]), "unfilled iOS icon slot"


if __name__ == "__main__":
    main()
