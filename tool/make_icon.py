# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10"]
# ///
"""Draws the LunaCare launcher icon: a crescent moon inside an orbit, with one
rouge bead on the orbit standing for her period (the same idea as the dial on
the Today screen).

Writes the source images that flutter_launcher_icons turns into app icons:
  assets/icon/icon.png             full icon on the night background
  assets/icon/icon_foreground.png  transparent layer for Android adaptive icons
  assets/icon/icon_monochrome.png  white silhouette for Android themed icons

Run from the project root, then regenerate the platform icons:
  uv run tool/make_icon.py
  dart run flutter_launcher_icons
"""

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 1024
SUPERSAMPLE = 4  # Draw large, then downsample, for smooth edges.

NIGHT = (30, 36, 54)  # #1E2436, the icon background
MOON = (243, 223, 168)  # #F3DFA8, the dial's moonlight
ROUGE = (224, 106, 120)  # #E06A78, her period
ORBIT = (214, 236, 240)  # #D6ECF0 月白, drawn translucent

BEAD_ANGLE = math.radians(-42)  # Upper right, where the crescent opens.


def disc(mask, cx, cy, r, value=255):
    ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=value)


def shapes(scale):
    """Coverage masks for the orbit, moon and bead, scaled about the centre."""
    size = SIZE * SUPERSAMPLE
    c = size / 2
    unit = size * scale

    orbit = Image.new("L", (size, size), 0)
    ring_r, ring_w = 0.34 * unit, 0.022 * unit
    disc(orbit, c, c, ring_r + ring_w / 2)
    disc(orbit, c, c, ring_r - ring_w / 2, 0)

    # The bead sits on the orbit with a little gap cut around it.
    bx = c + ring_r * math.cos(BEAD_ANGLE)
    by = c + ring_r * math.sin(BEAD_ANGLE)
    disc(orbit, bx, by, 0.078 * unit, 0)
    bead = Image.new("L", (size, size), 0)
    disc(bead, bx, by, 0.05 * unit)

    # A crescent: a disc with an offset disc taken out, opening to the bead.
    mx, my = c - 0.02 * unit, c + 0.015 * unit
    moon = Image.new("L", (size, size), 0)
    disc(moon, mx, my, 0.2 * unit)
    bite = Image.new("L", (size, size), 0)
    offset = 0.095 * unit
    disc(
        bite,
        mx + offset * math.cos(BEAD_ANGLE),
        my + offset * math.sin(BEAD_ANGLE),
        0.175 * unit,
    )
    return orbit, ImageChops.subtract(moon, bite), bead


def render(scale, background, paints):
    """paints: (colour, opacity 0-255) for the orbit, moon and bead."""
    size = SIZE * SUPERSAMPLE
    fill = background + (255,) if background else (0, 0, 0, 0)
    image = Image.new("RGBA", (size, size), fill)
    for mask, (colour, opacity) in zip(shapes(scale), paints):
        layer = Image.new("RGBA", (size, size), colour + (0,))
        layer.putalpha(mask.point(lambda v: v * opacity // 255))
        image = Image.alpha_composite(image, layer)
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main():
    out = Path("assets/icon")
    out.mkdir(parents=True, exist_ok=True)
    colour = [(ORBIT, 90), (MOON, 255), (ROUGE, 255)]
    white = [((255, 255, 255), 150), ((255, 255, 255), 255), ((255, 255, 255), 255)]
    render(1.0, NIGHT, colour).convert("RGB").save(out / "icon.png")
    # Adaptive icons crop to a circle or squircle, so the layers keep the
    # artwork inside the central safe zone.
    render(0.78, None, colour).save(out / "icon_foreground.png")
    render(0.78, None, white).save(out / "icon_monochrome.png")


if __name__ == "__main__":
    main()
