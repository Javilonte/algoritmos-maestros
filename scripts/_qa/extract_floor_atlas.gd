extends SceneTree

# Crops just the 8 floor tiles from the cyberpunk atlas into a clean
# atlas (without the checkerboard background). The atlas is laid out as
# 2 rows × 4 columns of floor diamonds; each diamond occupies a 256×128
# cell starting at y=200 in the source.
#
# Output: assets/textures/tilemap_cyberpunk_floors.png
# Size: 1024 × 256 (4 cols × 2 rows of 256×128 cells)
# The damero is stripped by treating only pixels WITHIN each diamond's
# bounding box as content (the diamond is a rhombus inscribed in the cell).

const SRC := "res://assets/textures/tilemap_cyberpunk.png"
const DST := "res://assets/textures/tilemap_cyberpunk_floors.png"

const TILE_W := 256
const TILE_H := 128
const COLS := 4
const ROWS := 2
const MARGIN_TOP := 200


func _init() -> void:
	var tex: Texture2D = load(SRC)
	var img: Image = tex.get_image()
	if img == null:
		print("FAIL")
		quit(1); return

	var out_w: int = COLS * TILE_W
	var out_h: int = ROWS * TILE_H
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)

	# For each cell: check whether pixel is "inside the diamond" (rhombus
	# inscribed in the cell). If outside the rhombus → alpha=0. If inside
	# → copy pixel from source.
	for row in range(ROWS):
		for col in range(COLS):
			var src_x := col * TILE_W
			var src_y := MARGIN_TOP + row * TILE_H
			var dst_x := col * TILE_W
			var dst_y := row * TILE_H
			for y in range(TILE_H):
				for x in range(TILE_W):
					if _inside_diamond(x, y):
						out.set_pixel(dst_x + x, dst_y + y, img.get_pixel(src_x + x, src_y + y))
					# else: alpha=0 by default

	out.save_png(DST)
	print("Saved %s  (%dx%d)" % [DST, out_w, out_h])
	quit(0)


func _inside_diamond(x: int, y: int) -> bool:
	# Rhombus inscribed in a 256x128 cell. Apex points at top/bottom/left/right.
	# The cell is wider than tall (2:1), so the diamond has slanted edges.
	# Center at (TILE_W/2, TILE_H/2).
	var cx: float = TILE_W / 2.0
	var cy: float = TILE_H / 2.0
	var dx: float = abs(x - cx) / (TILE_W / 2.0 - 1.0)
	var dy: float = abs(y - cy) / (TILE_H / 2.0 - 1.0)
	return dx + dy <= 1.0