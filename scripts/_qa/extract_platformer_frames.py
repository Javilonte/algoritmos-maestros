#!/usr/bin/env python3
"""Extract character frames from the cyberpunk character sheet.

Reads the PNG directly with PIL. The previous extractor
(scripts/_qa/extract_personaje_atlas.gd) had three defects that made the
shipped sprite sheets unusable:

  1. It read the texture through `load().get_image()`. The imported .ctex
     for this 8 MB atlas does not round-trip the colour, so the extractor
     worked on a corrupted copy.
  2. It used CELL_H=280. The character is ~390 px tall, so every frame was
     cropped through the body. That is why the extracted sheets showed
     boots in the top band and a head in the bottom band: the 280 px strip
     straddled the boundary between the IDLE row and the WALK row.
  3. The sheet has no alpha channel at all (PIL reports alpha extrema
     (255, 255)) — the transparency checker is baked in as real pixels, so
     no alpha threshold could recover it.

Frame isolation
---------------
The checker cannot be removed by colour: the character's skin sits at
(197, 192, 189) and the light checker block at the same position sits at
185..194. Any per-pixel threshold either keeps the checker or eats the
face. A periodic-plate subtraction was tried and also failed — the
checker's block pitch is 23 px but its dither is not phase-locked, so
neither a per-parity nor a per-phase plate reconstructs it.

So the character is found by WHERE it is, not by WHAT colour it is:

  1. The checker is removed with an 8-connected border flood fill over
     unsaturated pixels. 4-connectivity must not be used: the dither
     breaks 4-connected paths into ~13 000 fragments and the fill leaks.
  2. The FOREGROUND is closed with a 7x7 structuring element. The fill
     leaks through the character's dark outlines and near-grey clothing,
     chopping the body into ~140 fragments (largest component 123 px tall
     instead of 385). Closing the foreground bridges those gaps: the body
     becomes ONE component 385 px tall and 244 px wide.
  3. That component is filled, so the interior checker residue goes with
     it, and it is cropped to its own bounds.
  4. Every frame of a row is re-anchored into a UNIFORM cell with the
     character's feet on a common baseline and its body centred. The artist
     never aligned the frames — the head sits ~55 px into its cell in one
     frame and ~81 px in another — so the origin has to be normalised
     rather than taken from the cell grid. This is what stops the
     animation from jittering and the sprite from spilling out of frame.

Outputs
-------
  assets/textures/plat/personaje_<anim>_p.png   48 px tall, for the platformer
  assets/textures/personaje_<anim>.png          full resolution, for the battle
  resources/personaje_plat_spriteframes.tres    platformer
  resources/personaje_spriteframes.tres         battle and iso

The idle row carries a drone prop wired into the pose on several frames,
and a drone reads as a second character standing next to the player. The
idle animation therefore comes from the WALK row; INTERACT keeps its own
frames because the drone firing there IS the attack.

Usage:
  python3 scripts/_qa/extract_platformer_frames.py [--height N] [--detect]
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "textures", "personaje_cyberpunk.png")
PLAT_DIR = os.path.join(ROOT, "assets", "textures", "plat")

# Frame grid measured from the sheet: 8 frames of 328 px stride starting
# after the row label.
FRAME_X0 = 130
FRAME_STRIDE = 328
FRAME_COUNT = 8
LABEL_X = 140  # artwork to the right of this is a frame, not a row label

CHANNEL_TOL = 10
CLOSE_RADIUS = 3
MIN_COMPONENT = 800

# Atlas rows, and which cells of the third row belong to which animation.
# The third row holds INTERACT on the left and HURT on the right.
ROW_SPLIT = {"interact": (0, 4), "hurt": (4, 8)}


def load_rgba(path):
    return np.array(Image.open(path).convert("RGBA"), dtype=np.int16)


def background_mask(rgba):
    """True where the pixel is the baked-in transparency checker."""
    rgb = rgba[:, :, :3].astype(np.int32)
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    candidate = spread <= CHANNEL_TOL
    labels, _ = ndimage.label(candidate, structure=np.ones((3, 3), dtype=int))
    border = set(labels[0, :]) | set(labels[-1, :]) | set(labels[:, 0]) | set(labels[:, -1])
    border.discard(0)
    return np.isin(labels, list(border))


def foreground(rgba):
    """Artwork mask: background removed, then closed to repair the body."""
    fg = ~background_mask(rgba)
    return ndimage.binary_closing(
        fg, structure=np.ones((2 * CLOSE_RADIUS + 1, 2 * CLOSE_RADIUS + 1)), iterations=1
    )


def content_rows(fg):
    """Rows that hold artwork, ignoring the row-label column.

    A purely binary "any pixel" test does not separate the animation rows:
    stray props sit in the gap and keep it bridged. So the gap is found by
    density instead — a separator row holds a small fraction of the
    artwork row's pixel count.
    """
    counts = fg[:, LABEL_X:].sum(axis=1)
    has = counts > 0
    bands = []
    start = -1
    for y, v in enumerate(has):
        if v and start < 0:
            start = y
        elif not v and start >= 0:
            bands.append((start, y - 1))
            start = -1
    if start >= 0:
        bands.append((start, len(has) - 1))

    rows = []
    for b0, b1 in bands:
        seg = counts[b0 : b1 + 1]
        peak = int(seg.max()) if seg.size else 0
        if peak == 0:
            continue
        floor = max(20, int(peak * 0.08))
        sub_start = -1
        for i, c in enumerate(seg):
            y = b0 + i
            if c > floor and sub_start < 0:
                sub_start = y
            elif c <= floor and sub_start >= 0:
                rows.append((sub_start, y - 1))
                sub_start = -1
        if sub_start >= 0:
            rows.append((sub_start, b1))
    return rows


def character_pixels(fg, y0, y1, frame_index):
    """Boolean mask of the character for one frame.

    The character is the largest component above MIN_COMPONENT: it is
    ~46 000 px, the drone prop ~3 000 and the dither residue far less.
    The holes are filled so the checker residue inside the silhouette goes
    with it.
    """
    fx0 = FRAME_X0 + frame_index * FRAME_STRIDE
    fx1 = fx0 + FRAME_STRIDE - 1
    cell = fg[y0 : y1 + 1, fx0 : fx1 + 1]
    if cell.size == 0 or not cell.any():
        return None
    labels, count = ndimage.label(cell, structure=np.ones((3, 3), dtype=int))
    if count == 0:
        return None
    sizes = np.array(ndimage.sum(cell, labels, np.arange(1, count + 1)))
    keep = [i + 1 for i, s in enumerate(sizes) if s >= MIN_COMPONENT]
    if not keep:
        return None
    best = max(keep, key=lambda l: sizes[l - 1])
    return ndimage.binary_fill_holes(labels == best), fx0


def cut_frames(rgba, fg, y0, y1, cell_from=0, cell_to=FRAME_COUNT):
    """Cut the character out of each cell of a row, tight and aligned."""
    frames = []
    for i in range(cell_from, cell_to):
        found = character_pixels(fg, y0, y1, i)
        if found is None:
            continue
        mask, fx0 = found
        ys, xs = np.where(mask)
        if len(xs) == 0:
            continue
        bx0, bx1 = int(xs.min()), int(xs.max())
        by0, by1 = int(ys.min()), int(ys.max())
        sub = rgba[y0 + by0 : y0 + by1 + 1, fx0 + bx0 : fx0 + bx1 + 1].copy()
        sub[:, :, 3] = np.where(mask[by0 : by1 + 1, bx0 : bx1 + 1], sub[:, :, 3], 0)
        frames.append(sub.astype(np.uint8))
    return frames


def to_uniform_sheet(frames, target_h=0):
    """Pack frames into a run of uniform cells, feet on a common baseline."""
    if not frames:
        return None, []
    width = max(f.shape[1] for f in frames)
    height = max(f.shape[0] for f in frames)
    if target_h:
        scale = target_h / float(height)
        width = max(1, int(round(width * scale)))
        height = target_h
    cells = []
    for f in frames:
        if target_h:
            f = np.array(
                Image.fromarray(f, "RGBA").resize(
                    (max(1, int(round(f.shape[1] * scale))), target_h), Image.LANCZOS
                )
            )
        canvas = np.zeros((height, width, 4), dtype=np.uint8)
        canvas[height - f.shape[0] :, (width - f.shape[1]) // 2 : (width - f.shape[1]) // 2 + f.shape[1]] = f
        cells.append(canvas)
    sheet = np.concatenate(cells, axis=1)
    regions = [(i * width, width, height) for i in range(len(cells))]
    return sheet, regions


def write_spriteframes(path, sheet_dir, sheets, manifest):
    """Emit a SpriteFrames .tres using AtlasTexture SUB-RESOURCES.

    Each frame becomes an AtlasTexture sub-resource, not a "region" field.
    Godot's SpriteFrames parser ignores "region" in a .tres frame
    dictionary: the frame then draws the whole sheet, which is what made
    the player render as eight characters standing in a row.
    """
    names = list(sheets.keys())
    total = sum(len(sheets[n]) for n in names)
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]\n' % (len(names) + total + 1)]
    for i, name in enumerate(names, start=1):
        lines.append(
            '[ext_resource type="Texture2D" path="%s%s" id="%d_%s"]\n'
            % (sheet_dir, sheets[name], i, name)
        )
    lines.append("\n")
    for ni, name in enumerate(names):
        for fi, (x, w, h) in enumerate(manifest[name]["regions"]):
            lines.append('[sub_resource type="AtlasTexture" id="AtlasTexture_%s_%d"]\n' % (name, fi))
            lines.append('atlas = ExtResource("%d_%s")\n' % (ni + 1, name))
            lines.append('region = Rect2(%d, 0, %d, %d)\n' % (x, w, h))
            lines.append("\n")
    lines.append("[resource]\nanimations = [{\n")
    for ni, name in enumerate(names):
        regions = manifest[name]["regions"]
        lines.append('"frames": [{\n')
        for fi in range(len(regions)):
            lines.append('"duration": 1.0,\n')
            lines.append('"texture": SubResource("AtlasTexture_%s_%d")\n' % (name, fi))
            lines.append('}, {\n' if fi < len(regions) - 1 else '}],\n')
        lines.append('"loop": %s,\n' % ("false" if name == "interact" else "true"))
        lines.append('"name": &"%s",\n' % name)
        lines.append('"speed": 10.0\n')
        lines.append('}, {\n' if ni < len(names) - 1 else '}]\n')
    with open(path, "w") as fh:
        fh.write("".join(lines))
    print("wrote", os.path.relpath(path, ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--height", type=int, default=48, help="platformer sheet height in px")
    ap.add_argument("--detect", action="store_true")
    args = ap.parse_args()

    os.makedirs(PLAT_DIR, exist_ok=True)
    rgba = load_rgba(SRC)
    fg = foreground(rgba)
    bg = ~fg
    print("source %dx%d  background %.1f%%" % (rgba.shape[1], rgba.shape[0], 100.0 * bg.mean()))

    rows = content_rows(fg)
    art = [r for r in rows if r[1] - r[0] > 200]
    print("content row bands (>200 px tall):")
    for r in art:
        print("   y=%4d..%4d  h=%4d" % (r[0], r[1], r[1] - r[0] + 1))
    if args.detect:
        return 0
    if len(art) < 3:
        print("!! expected 3 animation rows, found", len(art))
        return 1

    walk = art[1]
    third = art[2]
    sources = {
        "idle": cut_frames(rgba, fg, walk[0], walk[1]),
        "walk": cut_frames(rgba, fg, walk[0], walk[1]),
        "interact": cut_frames(rgba, fg, third[0], third[1], *ROW_SPLIT["interact"]),
        "hurt": cut_frames(rgba, fg, third[0], third[1], *ROW_SPLIT["hurt"]),
    }

    # --- platformer sheets (48 px tall) ---
    plat_manifest = {}
    for name, frames in sources.items():
        sheet, regions = to_uniform_sheet(frames, args.height)
        if sheet is None:
            print("!! no frames for", name)
            continue
        path = os.path.join(PLAT_DIR, "personaje_%s_p.png" % name)
        Image.fromarray(sheet, "RGBA").save(path)
        plat_manifest[name] = {"regions": regions, "sheet": "personaje_%s_p.png" % name}
        print("plat %-9s frames=%d cell=%dx%d" % (name, len(regions), regions[0][1], regions[0][2]))
    with open(os.path.join(PLAT_DIR, "frames.json"), "w") as fh:
        json.dump(plat_manifest, fh, indent=1)
    write_spriteframes(
        os.path.join(ROOT, "resources", "personaje_plat_spriteframes.tres"),
        "res://assets/textures/plat/",
        {n: "personaje_%s_p.png" % n for n in plat_manifest},
        plat_manifest,
    )

    # --- full resolution sheets (battle portraits and the iso player) ---
    full_manifest = {}
    full_sheets = {}
    for name, frames in sources.items():
        sheet, regions = to_uniform_sheet(frames, 0)
        if sheet is None:
            continue
        path = os.path.join(ROOT, "assets", "textures", "personaje_%s.png" % name)
        Image.fromarray(sheet, "RGBA").save(path)
        full_sheets[name] = "personaje_%s.png" % name
        full_manifest[name] = {"regions": regions, "sheet": "personaje_%s.png" % name}
        print("full %-9s frames=%d cell=%dx%d" % (name, len(regions), regions[0][1], regions[0][2]))
    write_spriteframes(
        os.path.join(ROOT, "resources", "personaje_spriteframes.tres"),
        "res://assets/textures/",
        full_sheets,
        full_manifest,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
