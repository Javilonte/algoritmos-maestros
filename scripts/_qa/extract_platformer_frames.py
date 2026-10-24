#!/usr/bin/env python3
"""Extract platformer-ready character frames from the cyberpunk character sheet.

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
checker's block pitch is ~22.5 px, not an integer period, so a median
per phase reconstructs nothing (mean error 44 on empty ground).

So the character is found by WHERE it is, not by WHAT colour it is:

  1. The checker is removed with an 8-connected flood fill from the image
     border over unsaturated pixels (4-connectivity fragments the dither
     into ~13 000 pieces and leaks).
  2. Components smaller than MIN_COMPONENT are dropped: those are the
     dither residue the flood fill left behind.
  3. The character is the LARGEST component that TOUCHES THE GROUND LINE
     (the last row of the animation band, where the feet are). The drone
     prop that hovers beside the character in the idle row never touches
     the ground, and the cable prop that does is far smaller than the
     body. This is what separates the character from the extra sprites.
  4. Every frame of a row is cropped to the SAME box (the union of the
     character boxes), so the character keeps a constant position and
     stays fully inside its own frame. Cropping each frame to its own
     tight bounds is what made the animation jitter and spill outside
     the character.
  5. Only the character's pixels are kept, so the drone no longer reads
     as a second character standing next to the player.

Writes assets/textures/plat/*.png and
resources/personaje_plat_spriteframes.tres. The existing iso sheets are
left alone (resources/personaje_spriteframes.tres depends on their
344x280 regions).

Usage:
  python3 scripts/_qa/extract_platformer_frames.py [--height N] [--detect]
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "textures", "personaje_cyberpunk.png")
OUT_DIR = os.path.join(ROOT, "assets", "textures", "plat")

# Frame grid measured from the sheet: 8 frames of 328 px stride starting
# after the row label.
FRAME_X0 = 130
FRAME_STRIDE = 328
FRAME_COUNT = 8
LABEL_X = 140  # artwork to the right of this is a frame, not a row label

CHANNEL_TOL = 10
# Radius of the morphological closing applied to the FOREGROUND. The flood
# fill leaks through the character's dark outlines and near-grey clothing,
# chopping the body into ~140 fragments. Closing the foreground bridges
# those gaps: at r=3 the body becomes a single component 385 px tall and
# 244 px wide, which is the whole character.
CLOSE_RADIUS = 3
# Dither residue left by the flood fill is small; the drone prop is ~3000 px
# and the character is far larger, so this threshold drops residue only.
MIN_COMPONENT = 800


def load_rgba(path):
    return np.array(Image.open(path).convert("RGBA"), dtype=np.int16)


def background_mask(rgba):
    """True where the pixel is the baked-in transparency checker.

    The checker cannot be removed by colour: the character's skin is
    (197, 192, 189) and the light checker block at the same position sits
    at 185..194, so any threshold either keeps the checker or eats the
    face. A per-parity plate subtraction was tried and also failed (mean
    error 43 on empty ground) because the dither is not phase-locked.

    So the checker is removed structurally instead: it is unsaturated
    grey, and it reaches the image border. An 8-connected flood fill from
    the border over unsaturated pixels removes 76.7% of the image. 4
    connectivity must not be used: the dither breaks 4-connected paths
    into ~13000 fragments and the fill leaks.
    """
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


def build_row_sheet(rgba, fg, y0, y1, count=FRAME_COUNT):
    """Cut `count` frames out of one row band into a uniform-cell sheet.

    The artist did NOT align the character across frames — the head sits
    ~55 px into its cell in one frame and ~81 px in another. Cropping each
    frame to its own bounds and re-anchoring it fixes that: every frame
    goes into the same sized cell with the character's feet on a common
    baseline and its body centred on a common anchor. That is what stops
    the animation from jittering and the sprite from spilling outside its
    own frame.
    """
    frames = []
    for i in range(count):
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
    if not frames:
        return None

    width = max(f.shape[1] for f in frames)
    height = max(f.shape[0] for f in frames)
    cells = []
    for f in frames:
        canvas = np.zeros((height, width, 4), dtype=np.uint8)
        # Feet on the common baseline, body centred on the common anchor.
        dy = height - f.shape[0]
        dx = (width - f.shape[1]) // 2
        canvas[dy:, dx : dx + f.shape[1]] = f
        cells.append(canvas)

    sheet = np.concatenate(cells, axis=1)
    regions = [(i * width, width, height) for i in range(len(cells))]
    return sheet, regions


def save(sheet, name, target_h=0):
    img = Image.fromarray(sheet, "RGBA")
    if target_h and img.size[1] != target_h:
        w, h = img.size
        scale = target_h / float(h)
        img = img.resize((max(1, int(round(w * scale))), target_h), Image.LANCZOS)
    path = os.path.join(OUT_DIR, name)
    img.save(path)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--height", type=int, default=48, help="platformer sheet height in px")
    ap.add_argument("--detect", action="store_true")
    args = ap.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
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

    import json

    # The IDLE row carries a drone prop wired into the pose in several
    # frames, and a drone reads as a second character standing next to the
    # player. The WALK row is prop-free, so idle and walk both come from
    # it; the INTERACT row keeps its own frames because the drone firing
    # there IS the attack.
    sources = {"idle": art[1], "walk": art[1], "interact": art[2]}

    manifest = {}
    for name, band in sources.items():
        built = build_row_sheet(rgba, fg, band[0], band[1])
        if built is None:
            print("!! no frames for", name)
            continue
        sheet, regions = built
        full = save(sheet, "personaje_%s.png" % name)
        small = save(sheet, "personaje_%s_p.png" % name, args.height)
        scale = small.size[1] / float(full.size[1])
        scaled = [[int(round(x * scale)), int(round(w * scale)), small.size[1]] for x, w, h in regions]
        manifest[name] = {"regions": scaled, "sheet": "personaje_%s_p.png" % name}
        print(
            "%-9s band y=%d..%d  frames=%d  cell=%dx%d  sheet=%dx%d  platformer=%dx%d"
            % (name, band[0], band[1], len(regions), regions[0][1], regions[0][2],
               full.size[0], full.size[1], small.size[0], small.size[1])
        )
    with open(os.path.join(OUT_DIR, "frames.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    print("wrote", os.path.join(OUT_DIR, "frames.json"))
    write_spriteframes(manifest)
    return 0


def write_spriteframes(manifest):
    """Emit resources/personaje_plat_spriteframes.tres from the manifest.

    Each frame becomes an AtlasTexture SUB-RESOURCE, not a "region" field.
    Godot's SpriteFrames parser ignores "region" in a .tres frame dictionary:
    the frame then draws the whole sheet, which is what made the player
    render as eight characters standing in a row. The existing
    resources/personaje_spriteframes.tres already used AtlasTexture
    sub-resources for the same reason.
    """
    out = os.path.join(ROOT, "resources", "personaje_plat_spriteframes.tres")
    names = list(manifest.keys())
    total_frames = sum(len(manifest[n]["regions"]) for n in names)

    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]\n' % (len(names) + total_frames + 1)]
    for i, name in enumerate(names, start=1):
        lines.append(
            '[ext_resource type="Texture2D" path="res://assets/textures/plat/%s" id="%d_%s"]\n'
            % (manifest[name]["sheet"], i, name)
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
        for fi, region in enumerate(regions):
            lines.append('"duration": 1.0,\n')
            lines.append('"texture": SubResource("AtlasTexture_%s_%d")\n' % (name, fi))
            lines.append('}, {\n' if fi < len(regions) - 1 else '}],\n')
        lines.append('"loop": %s,\n' % ("false" if name == "interact" else "true"))
        lines.append('"name": &"%s",\n' % name)
        lines.append('"speed": 10.0\n')
        lines.append('}, {\n' if ni < len(names) - 1 else '}]\n')
    with open(out, "w") as fh:
        fh.write("".join(lines))
    print("wrote", out)


if __name__ == "__main__":
    sys.exit(main())
