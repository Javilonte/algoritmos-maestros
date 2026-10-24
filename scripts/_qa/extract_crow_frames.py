#!/usr/bin/env python3
"""Remove the baked-in checkerboard from the crow character sheet.

The crow atlas (cyberpunk_character_sprites_crow.png) has no alpha channel
and its transparency checker is baked in as real pixels, so the extracted
crow sheets carried a dark checkerboard box around the sprite. The
crow_walk.png and crow_idle.png in the repo were produced before that
checker was baked in, so they still show it.

Same technique as the player sheet: the checker is unsaturated grey that
reaches the image border, so an 8-connected border flood fill removes it,
and a morphological closing on the FOREGROUND reconnects the parts the
fill cut through.

ponytail: CHANNEL_TOL=14 alone was not enough. The dark checker squares
in this sheet are blue-tinted (about 32/32/48), so their channel spread is
16 — one notch ABOVE the old threshold. They survived the flood fill,
stayed in the same connected component as the character, and came out as
opaque grey slabs hanging around the art in the battle portrait.

ponytail: raising CHANNEL_TOL to 18 was the obvious fix and it was WRONG.
The character's own browns (72/64/56) have the SAME spread of 16, so the
threshold could not tell the two apart. At 18 the checker went away but
so did the hood of the first idle frame.

The real discriminator is HUE, not saturation: every checker square in
this atlas is BLUE-tinted (blue >= red) while every warm brown of the
character has red > blue. So the background candidate is "unsaturated AND
blue-tinted". The flood fill then eats the whole checker mesh from the
border and spares the character, even where it touches the cell edge.

Usage:
  python3 scripts/_qa/extract_crow_frames.py
  godot --headless --import
  godot --headless -s scripts/_qa/build_crow_spriteframes.gd

ponytail: the --import step is NOT optional. Godot serves the PNG through
its import cache, and a headless run does not re-import a changed source
on its own. Skip it and build_crow_spriteframes.gd reads the OLD sheet
size and writes the OLD cell regions back into the .tres — silently.
"""

import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "textures", "cyberpunk_character_sprites_crow.png")
OUT_DIR = os.path.join(ROOT, "assets", "textures")

CHANNEL_TOL = 18
# Minimum blue-over-red offset for a pixel to count as checker. The
# character's browns sit at -16, the checker's dark squares at +16.
COOL_MIN = 0
CLOSE_RADIUS = 3
MIN_COMPONENT = 400

# Row layout, from scripts/_qa/extract_crow_atlas.gd (manually verified).
ROWS = {
    "crow_idle": (0, [800, 1120, 1440, 1760]),
    "crow_walk": (320, [80, 400, 720, 1040, 1360, 1680, 2000]),
    "crow_attack": (640, [720, 1040, 1360, 1680]),
    "crow_hurt": (960, [1640, 1960]),
}
CELL = 320


def main():
    rgba = np.array(Image.open(SRC).convert("RGBA"), dtype=np.int16)
    rgb = rgba[:, :, :3].astype(np.int32)
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    cool = rgb[:, :, 2] - rgb[:, :, 0]

    # Unsaturated AND blue-tinted == checker. Everything else == art.
    candidate = (spread <= CHANNEL_TOL) & (cool >= COOL_MIN)
    labels, _ = ndimage.label(candidate, structure=np.ones((3, 3), dtype=int))
    border = set(labels[0, :]) | set(labels[-1, :]) | set(labels[:, 0]) | set(labels[:, -1])
    border.discard(0)
    bg = np.isin(labels, list(border))
    fg = ~bg
    fg = ndimage.binary_closing(
        fg, structure=np.ones((2 * CLOSE_RADIUS + 1, 2 * CLOSE_RADIUS + 1)), iterations=1
    )
    print("checker removed: %.1f%%" % (100.0 * bg.mean()))

    for name, (row_y, xs) in ROWS.items():
        frames = []
        for x in xs:
            cell = fg[row_y : row_y + CELL, x : x + CELL]
            cl, cn = ndimage.label(cell, structure=np.ones((3, 3), dtype=int))
            if cn == 0:
                frames.append(None)
                continue
            sizes = np.array(ndimage.sum(cell, cl, np.arange(1, cn + 1)))
            keep = [i + 1 for i, s in enumerate(sizes) if s >= MIN_COMPONENT]
            if not keep:
                frames.append(None)
                continue
            best = max(keep, key=lambda l: sizes[l - 1])
            mask = ndimage.binary_fill_holes(cl == best)
            ys, xs2 = np.where(mask)
            if len(xs2) == 0:
                frames.append(None)
                continue
            # Tight crop: the art only, no atlas padding.
            bx0, bx1 = int(xs2.min()), int(xs2.max())
            by0, by1 = int(ys.min()), int(ys.max())
            sub = rgba[row_y + by0 : row_y + by1 + 1, x + bx0 : x + bx1 + 1].copy()
            sub[:, :, 3] = np.where(mask[by0 : by1 + 1, bx0 : bx1 + 1], sub[:, :, 3], 0)
            frames.append(sub.astype(np.uint8))

        usable = [f for f in frames if f is not None]
        if not usable:
            print("!! no frames for", name)
            continue

        # Re-anchor into a run of uniform cells with the body centred and the
        # feet on a common baseline. The atlas cells have the art at a
        # different offset in every frame, so without this the crow drifts
        # inside its frame and hangs out of the battle portrait's box.
        width = max(f.shape[1] for f in usable)
        height = max(f.shape[0] for f in usable)
        cells = []
        for f in usable:
            canvas = np.zeros((height, width, 4), dtype=np.uint8)
            dx = (width - f.shape[1]) // 2
            canvas[height - f.shape[0] :, dx : dx + f.shape[1]] = f
            cells.append(canvas)
        sheet = np.concatenate(cells, axis=1)
        path = os.path.join(OUT_DIR, name + ".png")
        Image.fromarray(sheet, "RGBA").save(path)
        print("wrote %-28s %dx%d  (%d frames, cell %dx%d)" % (
            name + ".png", sheet.shape[1], sheet.shape[0], len(usable), width, height))
    return 0


if __name__ == "__main__":
    sys.exit(main())
