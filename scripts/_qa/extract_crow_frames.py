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

Usage:
  python3 scripts/_qa/extract_crow_frames.py
"""

import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "textures", "cyberpunk_character_sprites_crow.png")
OUT_DIR = os.path.join(ROOT, "assets", "textures")

CHANNEL_TOL = 14
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

    labels, _ = ndimage.label(spread <= CHANNEL_TOL, structure=np.ones((3, 3), dtype=int))
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
            sub = rgba[row_y : row_y + CELL, x : x + CELL].copy()
            sub[:, :, 3] = np.where(mask, sub[:, :, 3], 0)
            frames.append(sub.astype(np.uint8))

        usable = [f for f in frames if f is not None]
        if not usable:
            print("!! no frames for", name)
            continue
        sheet = np.concatenate(usable, axis=1)
        path = os.path.join(OUT_DIR, name + ".png")
        Image.fromarray(sheet, "RGBA").save(path)
        print("wrote %-28s %dx%d  (%d frames)" % (name + ".png", sheet.shape[1], sheet.shape[0], len(usable)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
