extends SceneTree

# Extracts the cyberpunk crow enemy atlases from the source character sheet.
# The crow has 4 animation rows: IDLE, WALK, ATTACK, HURT.
# Stride is 320 px; cells are 320 wide x 320 tall.
#
# Layout (manually verified by inspecting the atlas with grid lines):
#   Row 0 IDLE    : y=0..320,    4 frames at x = 800, 1120, 1440, 1760
#                    (the first cell x=480..800 contains a label/preview
#                    that we skip).
#   Row 1 WALK    : y=320..640,  7 frames at x = 80, 400, 720, 1040, 1360, 1680, 2000
#   Row 2 ATTACK  : y=640..960,  4 frames at x = 720, 1040, 1360, 1680
#   Row 3 HURT    : y=960..1280, 2 frames at x = 1640, 1960
#
# Within each cell, the sprite body occupies the center; the corner regions
# are checkerboard padding. We zero alpha in the corner regions for clean
# rendering on any background.

const SRC := "res://assets/textures/cyberpunk_character_sprites_crow.png"
const OUT_DIR := "res://assets/textures/"

const CELL_W := 320
const CELL_H := 320
const SHRINK := 12  # pixels to trim from each side of the cell


func _init() -> void:
	var tex: Texture2D = load(SRC)
	var img: Image = tex.get_image()
	if img == null:
		print("FAIL: cannot load %s" % SRC)
		quit(1); return
	var w := img.get_width()
	var h := img.get_height()

	# IDLE: 4 frames, starting at column 1 (skip the preview cell at col 0).
	_extract_row(img, "crow_idle", 0, [800, 1120, 1440, 1760], w, h)
	# WALK: 7 frames starting at column 0.
	_extract_row(img, "crow_walk", 1, [80, 400, 720, 1040, 1360, 1680, 2000], w, h)
	# ATTACK: 4 frames starting at column 0.
	_extract_row(img, "crow_attack", 2, [720, 1040, 1360, 1680], w, h)
	# HURT: 2 frames (these are the platform-stand sprites, used for the
	# "spawn / appear" animation).
	_extract_row(img, "crow_hurt", 3, [1640, 1960], w, h)

	quit(0)


func _extract_row(img: Image, name: String, row: int, x_starts: Array, src_w: int, src_h: int) -> void:
	var src_y: int = row * CELL_H
	var count: int = x_starts.size()
	var out_w: int = count * CELL_W
	var out_h: int = CELL_H
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)

	var keep_left: int = SHRINK
	var keep_right: int = CELL_W - SHRINK
	var keep_top: int = SHRINK
	var keep_bot: int = CELL_H - SHRINK

	for i in range(count):
		var src_x: int = x_starts[i]
		var dst_x: int = i * CELL_W
		for y in range(CELL_H):
			for x in range(CELL_W):
				var p := img.get_pixel(src_x + x, src_y + y)
				var inside: bool = x >= keep_left and x < keep_right and y >= keep_top and y < keep_bot
				if not inside:
					p.a = 0.0
				# ponytail: raise the alpha floor to 0.9 — same fix as
				# personaje: the source atlas can have semi-transparent
				# checkerboard residue (alpha 50-199) inside the keep
				# region from prior extractions. Body silhouette is
				# always alpha >= 0.9, so anything below is background.
				elif p.a < 0.9:
					p.a = 0.0
				out.set_pixel(dst_x + x, y, p)

	var out_path: String = "%s%s.png" % [OUT_DIR, name]
	out.save_png(out_path)
	print("Saved %s  (%dx%d, %d frames)" % [out_path, out_w, out_h, count])