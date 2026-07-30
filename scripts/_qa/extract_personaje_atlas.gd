extends SceneTree

# Final extraction: hard-coded stride of 328 px based on manual measurement.
# Frame 0 (label/preview) is skipped for each animation.
#
# Source: assets/textures/personaje_cyberpunk.png (2752x1536, RGBA).
# After the title bar (y=0..200), each 320-px row contains:
#   - IDLE/WALK:    8 cells of 328 px stride, starting at x=130 (after label).
#   - INTERACT/HURT: 4 cells each at the same stride (interact at x=130, hurt at x=1442).
# Within each cell, the sprite occupies the bottom 80% of the cell height
# (top is label/padding). We also clean the corner pixels for clean alpha.

const SRC := "res://assets/textures/personaje_cyberpunk.png"
const OUT_DIR := "res://assets/textures/"

const CELL_W := 344          # measured stride between sprites
const CELL_H := 280          # row height for sprite content (excluding label)
const SPRITE_X_OFFSET := 130  # x of first sprite after IDLE label
const BODY_Y := 240          # IDLE label is at y=200..240; sprites start at y=240
const LABEL_OFFSET := 130    # width of IDLE/WALK labels (px)


func _init() -> void:
	var tex: Texture2D = load(SRC)
	var img: Image = tex.get_image()
	if img == null:
		print("FAIL")
		quit(1); return
	var w := img.get_width()
	var h := img.get_height()

	# ponytail: compute the actual frame count from the atlas width.
	# Each animation row skips the first cell (label) and reads cells of
	# CELL_W px width. The previous hardcoded count=8 produced two empty
	# frames at the tail because the atlas is 2752 px wide and only 6
	# frames fit after the 130-px label offset (stride 344).
	var idle_count: int = (w - SPRITE_X_OFFSET - CELL_W) / CELL_W
	var walk_count: int = idle_count  # WALK row has same layout
	var interact_count: int = 4
	var hurt_count: int = 4

	_extract(img, "personaje_idle", 0, idle_count, 1, w, h)
	_extract(img, "personaje_walk", 1, walk_count, 1, w, h)
	_extract(img, "personaje_interact", 2, interact_count, 1, w, h)
	# HURT: 4 frames from row 2 (starting after INTERACT).
	# INTERACT ends at x = 130 + 4*328 = 1442. HURT starts at x=1442.
	_extract_hurt(img, w, h)

	quit(0)


func _extract(img: Image, name: String, row: int, count: int, skip: int, src_w: int, src_h: int) -> void:
	var src_y: int = BODY_Y + row * CELL_H
	var out_w: int = count * CELL_W
	var out_h: int = CELL_H
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	for i in range(count):
		var src_x: int = SPRITE_X_OFFSET + (i + skip) * CELL_W
		var dst_x: int = i * CELL_W
		_copy_region(img, out, src_x, src_y, dst_x, 0, CELL_W, CELL_H, src_w, src_h)
	var out_path: String = "%s%s.png" % [OUT_DIR, name]
	out.save_png(out_path)
	print("Saved %s  (%dx%d, %d frames)" % [out_path, out_w, out_h, count])


func _extract_hurt(img: Image, src_w: int, src_h: int) -> void:
	# INTERACT occupies columns 1..4 of row 2 (skipping label at col 0).
	# HURT occupies columns 5..8 of row 2 (its label is at col 4).
	# ponytail: compute actual count from atlas width so we don't emit
	# empty trailing frames from overflow.
	var src_y: int = BODY_Y + 2 * CELL_H
	var hurt_first_x: int = SPRITE_X_OFFSET + (4 + 1) * CELL_W
	var max_count: int = (src_w - hurt_first_x) / CELL_W
	var out_w: int = max_count * CELL_W
	var out_h: int = CELL_H
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	for i in range(max_count):
		var src_x: int = hurt_first_x + i * CELL_W
		var dst_x: int = i * CELL_W
		_copy_region(img, out, src_x, src_y, dst_x, 0, CELL_W, CELL_H, src_w, src_h)
	var out_path: String = "%s%shurt.png" % [OUT_DIR, "personaje_"]
	out.save_png(out_path)
	print("Saved %s  (%dx%d, %d frames)" % [out_path, out_w, out_h, max_count])


func _copy_region(
	src: Image, dst: Image,
	src_x: int, src_y: int, dst_x: int, dst_y: int,
	w: int, h: int, src_w: int, src_h: int
) -> void:
	for y in range(h):
		for x in range(w):
			var sx: int = src_x + x
			var sy: int = src_y + y
			if sx < 0 or sx >= src_w or sy < 0 or sy >= src_h:
				continue
			var p := src.get_pixel(sx, sy)
			# Clean low-alpha pixels (checker residue).
			if p.a < 0.15:
				p.a = 0.0
			dst.set_pixel(dst_x + x, dst_y + y, p)