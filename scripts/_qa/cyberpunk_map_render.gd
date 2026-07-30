extends Node2D

# Renders the cyberpunk atlas as a hand-placed grid of Sprite2D nodes.
# Each diamond tile is rendered at iso positions (TILE_W/2, TILE_H/2)
# offset from the previous tile. This avoids the TileSet coordinate
# system entirely — we paint in screen-space pixels using the iso math
# from iso_coords.gd but with TILE_W=256, TILE_H=128 to match the atlas.
#
# ponytail: this is a deliberate shortcut to ship the MVP without
# rewriting iso_coords.gd. The IsoPlayer still moves at 200 px/s in
# screen-space; the painted tiles are visual decoration, not collision.
#
# Map design (a small cyberpunk plaza, 9x9 tiles = ~17x17 visible):
#   - Center: clean floor
#   - Corners: broken/destroyed floor
#   - Edges: industrial grate
#   - A few containers and signs as standalone props
#
# Tile IDs are sourced from IsoTileCoords (the central catalog) so the
# atlas layout can evolve without touching this QA render.

const IsoTileCoordsScript := preload("res://scripts/iso/iso_tile_coords.gd")

const ATLAS_PATH := "res://assets/textures/tilemap_cyberpunk_floors.png"
const TILE_W := 256
const TILE_H := 128
const MARGIN_TOP := 0  # cropped atlas starts at y=0
const GRID_CENTER := Vector2i(4, 4)  # (4,4) is the screen center of the 9x9 grid


func _ready() -> void:
	# Use a SubViewport for capture so we don't fight the main window's
	# editor-themed transparent background (which renders as a checkerboard
	# in headless mode).
	var sv := SubViewport.new()
	sv.size = Vector2i(1152, 648)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	# Build the world inside the SubViewport.
	var world := Node2D.new()
	sv.add_child(world)

	# Dark cyberpunk background — solid ColorRect inside the SubViewport.
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 1)
	bg.size = Vector2(4000, 4000)
	bg.position = Vector2(-2000, -2000)
	bg.z_index = -100
	world.add_child(bg)

	var tex: Texture2D = load(ATLAS_PATH)
	if tex == null:
		push_error("Cannot load atlas")
		get_tree().quit(1); return
	var deku_scene: PackedScene = load("res://scenes/iso/iso_player.tscn")
	if deku_scene == null:
		push_error("Cannot load deku scene")
		get_tree().quit(1); return
	_continue_build(world, tex, deku_scene)


func _continue_build(world: Node2D, tex: Texture2D, deku_scene: PackedScene) -> void:

	# Paint a 9x9 grid centered on screen.
	# Grid coords: (gx, gy) ∈ [0..8]². Origin (4, 4) is the screen center.
	var grid_size := 9
	var origin_x := 576  # screen center X
	var origin_y := 324  # screen center Y

	# Tile palette: deterministic pattern.
	# Use a simple hash-based selection per (gx, gy).
	for gy in range(grid_size):
		for gx in range(grid_size):
			var atlas_coord := _pick_tile(gx, gy)
			var screen_pos := _iso_pos(gx, gy, origin_x, origin_y)
			world.add_child(_make_sprite(tex, atlas_coord, screen_pos))

	# Camera centered on the grid inside the SubViewport.
	var cam := Camera2D.new()
	world.add_child(cam)
	cam.global_position = Vector2(origin_x, origin_y)
	cam.make_current()

	# Add Deku player at the center of the grid.
	var deku: Node2D = deku_scene.instantiate()
	world.add_child(deku)
	deku.global_position = Vector2(origin_x, origin_y - 32)

	for i in range(4):
		await get_tree().process_frame

	var img: Image = (world.get_parent() as SubViewport).get_texture().get_image()
	if img:
		img.save_png("/tmp/cyberpunk_map.png")
		print("Saved /tmp/cyberpunk_map.png")
	get_tree().quit(0)


func _iso_pos(gx: int, gy: int, ox: int, oy: int) -> Vector2:
	# Standard iso projection: screen = ((gx - gy) * tile_w/2, (gx + gy) * tile_h/2)
	# Origin (4, 4) maps to screen (ox, oy).
	var half_w: float = TILE_W / 2.0
	var half_h: float = TILE_H / 2.0
	var dx: float = (gx - gy) * half_w
	var dy: float = (gx + gy) * half_h
	return Vector2(ox + dx, oy + dy)


func _pick_tile(gx: int, gy: int) -> Vector2i:
	# Returns the same tile the playable demo uses, anchored on the QA
	# grid's center. Toxic pool is reserved for the playable map (not QA).
	return IsoTileCoordsScript.cyber_floor_for(gx, gy, GRID_CENTER)


func _make_sprite(tex: Texture2D, atlas_coord: Vector2i, pos: Vector2) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(
		atlas_coord.x * TILE_W,
		MARGIN_TOP + atlas_coord.y * TILE_H,
		TILE_W, TILE_H,
	)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	# Diamond center is at (TILE_W/2, TILE_H/2) within the atlas cell —
	# offset the sprite so its top-of-diamond anchors at `pos`.
	sprite.centered = true
	sprite.position = pos
	return sprite