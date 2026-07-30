extends Node2D

# Cyberpunk iso world: paints the cyberpunk floor tiles as Sprite2D nodes
# arranged in iso-grid positions. Uses the cleaned atlas
# (assets/textures/tilemap_cyberpunk_floors.png) with 8 floor tiles in a
# 4x2 grid (each 256x128 diamond).
#
# ponytail: this replaces the procedural tile-based world (which painted
# nothing, leaving a green background visible). The cyberpunk world is
# hand-built here for an MVP-presentable map.

const IsoCoordsScript := preload("res://scripts/iso/iso_coords.gd")
const IsoTileCoordsScript := preload("res://scripts/iso/iso_tile_coords.gd")

const ATLAS_PATH := "res://assets/textures/tilemap_cyberpunk_floors.png"
const TILE_W := 256
const TILE_H := 128

## Map dimensions in iso-grid cells.
@export var map_radius: int = 4

## Hard-coded enemy spawns. Each entry is a tile-space (gx, gy) on the
## iso grid. The crow enemy spawns here, walks around its home tile,
## and triggers a battle when the player walks into its hitbox.
## ponytail: spawns are placed on the cardinal axes (g_y=0 or g_x=0) so
## the player's input-to-velocity iso projection lands on the crow's
## home tile. The previous off-axis spawns (3,-2), (-3,2), (2,3) were
## unreachable: the player walks in 8 iso directions and could never get
## within the hit radius of those positions.
const CROW_SPAWNS: Array[Vector2i] = [
	Vector2i(2, 0),    # east 2 (player walks E)
	Vector2i(-2, 0),   # west 2 (player walks W)
	Vector2i(0, 2),    # south 2 (player walks S)
]

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var player: CharacterBody2D = $IsoPlayer
@onready var enemies_container: Node2D = $Enemies
@onready var level_up_toast: CanvasLayer = $LevelUpToast


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	_paint_background()
	_paint_floor_grid()
	_paint_decoration()
	_spawn_crows()
	_position_player()
	# ponytail: surface level-up events from the SkillTree. The toast is
	# hidden by default and fades in only when XP actually crosses a
	# threshold (SkillTree.add_xp gates the level_changed signal).
	if level_up_toast and level_up_toast.has_method("connect_to_skill_tree"):
		level_up_toast.connect_to_skill_tree()
	if player:
		EventBus.player_spawned.emit(player)


func _paint_background() -> void:
	# Background is handled by project.godot's default_clear_color (gray).
	# Don't add a ColorRect/Sprite here — covering the full viewport with
	# a background sprite occludes the floor tiles in headless capture.
	pass


func _paint_floor_grid() -> void:
	# 8 floor tiles from the atlas in a 4x2 grid (cols, rows).
	# Paint a DIAMOND of radius `map_radius` (not a square) so the
	# visible map fits the screen viewport. Each cell (gx, gy) is kept
	# iff |gx| + |gy| <= map_radius. The IsoDemo node is positioned at
	# the iso origin (576, 540), so tiles are placed in local coords.
	var tex: Texture2D = load(ATLAS_PATH)
	if tex == null:
		push_error("Cannot load cyberpunk atlas")
		return
	var origin: Vector2 = Vector2.ZERO  # IsoDemo is at (576, 540) world-space

	for gy in range(-map_radius, map_radius + 1):
		for gx in range(-map_radius, map_radius + 1):
			if abs(gx) + abs(gy) > map_radius:
				continue
			var atlas_coord: Vector2i = _pick_tile(gx, gy)
			var screen_pos: Vector2 = _iso_pos(gx, gy, origin)
			_add_tile_sprite(tex, atlas_coord, screen_pos, gx, gy)
	print("Floor grid painted with %d sprites" % get_child_count())


func _add_tile_sprite(tex: Texture2D, atlas_coord: Vector2i, pos: Vector2, gx: int, gy: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(atlas_coord.x * TILE_W, atlas_coord.y * TILE_H, TILE_W, TILE_H)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = true
	sprite.position = pos
	# y-sort: tiles further south (higher gy) draw on top.
	sprite.z_index = -500 + gy
	add_child(sprite)


func _paint_decoration() -> void:
	# A handful of decorative props from the original atlas (containers,
	# signs, drone) placed at strategic positions on the grid.
	# For now, keep this empty — main MVP is the floor grid.
	pass


func _spawn_crows() -> void:
	# Spawn a crow enemy at each CROW_SPAWNS tile. The crow's own
	# _ready() converts tile coords to iso screen space.
	if enemies_container == null:
		return
	var crow_scene: PackedScene = load("res://scenes/iso/crow_enemy.tscn") as PackedScene
	if crow_scene == null:
		push_warning("Crow enemy scene not found")
		return
	for spawn_tile in CROW_SPAWNS:
		var crow: CharacterBody2D = crow_scene.instantiate() as CharacterBody2D
		if crow == null:
			continue
		crow.tile_position = spawn_tile
		enemies_container.add_child(crow)


func _iso_pos(gx: int, gy: int, origin: Vector2) -> Vector2:
	var half_w: float = TILE_W / 2.0
	var half_h: float = TILE_H / 2.0
	var dx: float = (gx - gy) * half_w
	var dy: float = (gx + gy) * half_h
	return Vector2(origin.x + dx, origin.y + dy)


func _pick_tile(gx: int, gy: int) -> Vector2i:
	# ponytail: routes through the central catalog so the atlas layout can
	# change without rewriting this file. The catalog preserves the MVP
	# pattern: center plain, edges broken, corners destroyed.
	return IsoTileCoordsScript.cyber_floor_for(gx, gy)


func _position_player() -> void:
	if player_spawn and player:
		player.global_position = player_spawn.global_position