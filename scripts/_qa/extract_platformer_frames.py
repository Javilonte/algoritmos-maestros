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
     no alpha threshold could recover it. Here the checker is detected by
     an 8-connected flood fill from the image border and made transparent.

Geometry is measured from the atlas rather than assumed:
  - the frame grid is the 328 px stride the sheet actually uses
    ((2752 - 130) / 8 = 327.75);
  - the row bands come from the per-row content profile;
  - each frame is cropped to its own alpha bounding box and bottom-aligned,
    so feet sit on a common baseline whatever the pose does.

Writes NEW files under assets/textures/plat/ and leaves the existing iso
sheets alone (resources/personaje_spriteframes.tres depends on their
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


def load_rgba(path):
    return np.array(Image.open(path).convert("RGBA"), dtype=np.int16)


def background_mask(rgba):
    rgb = rgba[:, :, :3].astype(np.int32)
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    candidate = spread <= CHANNEL_TOL
    labels, _ = ndimage.label(candidate, structure=np.ones((3, 3), dtype=int))
    border = set(labels[0, :]) | set(labels[-1, :]) | set(labels[:, 0]) | set(labels[:, -1])
    border.discard(0)
    return np.isin(labels, list(border))


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


def frame_bbox(fg, x0, x1, y0, y1):
    """Alpha bounding box of one frame cell, ignoring the label column."""
    cell = fg[y0 : y1 + 1, x0 : x1 + 1]
    if cell.size == 0 or not cell.any():
        return None
    cols = np.where(cell.any(axis=0))[0]
    rows = np.where(cell.any(axis=1))[0]
    if len(cols) == 0 or len(rows) == 0:
        return None
    return (x0 + int(cols[0]), x0 + int(cols[-1]), y0 + int(rows[0]), y0 + int(rows[-1]))


def build_row_sheet(rgba, fg, y0, y1, count=FRAME_COUNT):
    """Cut `count` frames out of one row band.

    Each frame is cropped to its own alpha bounding box so the sheet has no
    dead space, but every frame is bottom-aligned on a common baseline so
    the feet stay on the ground whatever the pose does. Frame widths differ
    (the idle poses carry drone props), so the sheet is a run of
    variable-width cells and the regions are returned for the SpriteFrames.
    """
    boxes = []
    for i in range(count):
        fx0 = FRAME_X0 + i * FRAME_STRIDE
        fx1 = fx0 + FRAME_STRIDE - 1
        bb = frame_bbox(fg, fx0, fx1, y0, y1)
        if bb:
            boxes.append(bb)
    if not boxes:
        return None

    max_y = max(b[3] for b in boxes)
    min_y = min(b[2] for b in boxes)
    h = max_y - min_y + 1

    frames = []
    for bb in boxes:
        sub = rgba[bb[2] : bb[3] + 1, bb[0] : bb[1] + 1].copy()
        sub[:, :, 3] = fg[bb[2] : bb[3] + 1, bb[0] : bb[1] + 1] * 255
        canvas = np.zeros((h, sub.shape[1], 4), dtype=np.uint8)
        dy = max_y - bb[3]  # bottom aligned
        canvas[dy : dy + sub.shape[0]] = sub.astype(np.uint8)
        frames.append(canvas)

    sheet = np.concatenate(frames, axis=1)
    regions = []
    x = 0
    for f in frames:
        regions.append((x, f.shape[1], h))
        x += f.shape[1]
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
    bg = background_mask(rgba)
    fg = ~bg
    print("source %dx%d  background %.1f%%" % (rgba.shape[1], rgba.shape[0], 100.0 * bg.mean()))

    rows = content_rows(fg)
    art = [r for r in rows if r[1] - r[0] > 200]
    print("content row bands (>200 px tall):")
    for r in art:
        print("   y=%4d..%4d  h=%4d" % (r[0], r[1], r[1] - r[0] + 1))
    if args.detect:
        return 0

    # The sheet's animation rows, in order: IDLE, WALK, INTERACT/HURT.
    if len(art) < 3:
        print("!! expected 3 animation rows, found", len(art))
        return 1

    import json

    manifest = {}
    for name, band in zip(("idle", "walk", "interact"), art):
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
            "%-9s band y=%d..%d  frames=%d  sheet=%dx%d  platformer=%dx%d  regions=%s"
            % (name, band[0], band[1], len(regions), full.size[0], full.size[1],
               small.size[0], small.size[1], scaled)
        )
    with open(os.path.join(OUT_DIR, "frames.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    print("wrote", os.path.join(OUT_DIR, "frames.json"))
    write_spriteframes(manifest)
    return 0


def write_spriteframes(manifest):
    """Emit resources/personaje_plat_spriteframes.tres from the manifest."""
    out = os.path.join(ROOT, "resources", "personaje_plat_spriteframes.tres")
    names = list(manifest.keys())
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]\n' % (len(names) + 1)]
    for i, name in enumerate(names, start=1):
        lines.append(
            '[ext_resource type="Texture2D" path="res://assets/textures/plat/%s" id="%d_%s"]\n'
            % (manifest[name]["sheet"], i, name)
        )
    lines.append("\n[resource]\nanimations = [{\n")
    for ni, name in enumerate(names):
        regions = manifest[name]["regions"]
        lines.append('"frames": [{\n')
        for fi, region in enumerate(regions):
            x, w, h = region
            lines.append('"duration": 1.0,\n')
            lines.append('"texture": ExtResource("%d_%s"),\n' % (ni + 1, name))
            lines.append('"region": Rect2(%d, 0, %d, %d)\n' % (x, w, h))
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
