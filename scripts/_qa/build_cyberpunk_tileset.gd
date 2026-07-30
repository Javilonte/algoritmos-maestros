extends SceneTree

# One-shot script that builds the cyberpunk TileSet programmatically and
# saves it as scenes/iso/tilesets/iso_cyberpunk_256x128.tres.
# Run: godot --headless -s scripts/_qa/build_cyberpunk_tileset.gd --quit-after 30
#
# ponytail: this saves the resource directly because the .tres format
# round-trip is fragile for TileSetAtlasSource (auto-tile population only
# happens in the editor). Programmatic creation gives us a working .tres
# that we can verify with smoke tests.

const ATLAS_PATH := "res://assets/textures/tilemap_cyberpunk_floors.png"
const OUT_PATH := "res://scenes/iso/tilesets/iso_cyberpunk_256x128.tres"

const TILE_W := 256
const TILE_H := 128
const COLS := 4
const ROWS := 2
const MARGIN_TOP := 0  # atlas starts at y=0 (already cropped)


func _init() -> void:
	var tex: Texture2D = load(ATLAS_PATH)
	if tex == null:
		push_error("Cannot load %s" % ATLAS_PATH)
		quit(1); return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_W, TILE_H)
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_W, TILE_H)
	src.margins = Vector2i(0, MARGIN_TOP)
	src.separation = Vector2i(0, 0)
	src.use_texture_padding = false

	# Create tiles for each (col, row) in the atlas body.
	for row in range(ROWS):
		for col in range(COLS):
			var coords := Vector2i(col, row)
			src.create_tile(coords)
			var data := src.get_tile_data(coords, 0)
			if data:
				data.texture_origin = Vector2i(0, 0)

	ts.add_source(src)
	print("Built TileSet: %d tiles, source count=%d" % [src.get_tiles_count(), ts.get_source_count()])

	var save_err := ResourceSaver.save(ts, OUT_PATH)
	if save_err != OK:
		push_error("Failed to save %s: %d" % [OUT_PATH, save_err])
		quit(1); return
	print("Saved %s" % OUT_PATH)

	# Verify by reloading.
	var reloaded := load(OUT_PATH) as TileSet
	if reloaded == null:
		push_error("Failed to reload %s" % OUT_PATH)
		quit(1); return
	print("Reload OK: tile_size=%s, sources=%d" % [reloaded.tile_size, reloaded.get_source_count()])
	var reloaded_src := reloaded.get_source(0) as TileSetAtlasSource
	if reloaded_src:
		print("Source tiles: %d  texture: %s" % [reloaded_src.get_tiles_count(), reloaded_src.texture])
	quit(0)