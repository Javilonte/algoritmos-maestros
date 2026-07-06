extends Node2D

const _IsoCoordsScript := preload("res://scripts/iso/iso_coords.gd")
const _IsoEnemyScene := preload("res://scenes/iso/iso_enemy.tscn")
const _IsoTileCoordsScript := preload("res://scripts/iso/iso_tile_coords.gd")

@onready var base_layer: TileMapLayer = $TileMapLayers/Base
@onready var ground_layer: TileMapLayer = $TileMapLayers/Ground
@onready var extended_layer: TileMapLayer = $TileMapLayers/Extended
@onready var microfantasy_layer: TileMapLayer = $TileMapLayers/Microfantasy/MicrofantasyGround
@onready var walls_layer: TileMapLayer = $TileMapLayers/Walls
@onready var decor_layer: TileMapLayer = $TileMapLayers/Decor
@onready var props_layer: TileMapLayer = $TileMapLayers/Props
@onready var decoration_layer: TileMapLayer = $TileMapLayers/Decoration
@onready var enemies_container: Node2D = $Enemies
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var player: CharacterBody2D = $IsoPlayer

@export var iso_meta: Resource

const SRC_ORIGINAL: int = 0
const SRC_EXTENDED: int = 1
const SRC_WALLS: int = 0
const SRC_DECOR: int = 0
const SRC_PROPS: int = 0

const TILE_GRASS: int = 2
const TILE_PATH_YELLOW: int = 3
const TILE_PATH_ORANGE: int = 4
const TILE_BASE_MAGENTA: int = 12

const MF_TILE_GRASS_ROW: int = 1
const MF_TILE_WATER_ROW: int = 2
const MF_TILE_SAND_ROW: int = 4
const MF_TILE_PATH_ROW: int = 6
const MF_TILE_TREE_ROW: int = 10
const MF_TILE_ROCK_ROW: int = 8


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	if iso_meta == null:
		push_error("IsoDemoWorld: iso_meta not assigned")
		return
	_populate_base()
	_populate_ground_with_grass_covering_all()
	_populate_interior_floors()
	_carve_horizontal_path_original()
	if bool(iso_meta.use_extended_terrain):
		_paint_lakes_extended()
		_paint_forest_patches_extended()
	_populate_walls_from_regions()
	_populate_doors()
	_populate_decor_items()
	_populate_props()
	_populate_decoration_original()
	if IsoAtlasBuilder.has_microfantasy():
		_paint_with_microfantasy()
	_spawn_enemies()
	_position_player()
	EventBus.player_spawned.emit(player)


# ============================================================
# Base ring + full grass coverage
# ============================================================
func _populate_base() -> void:
	var padding: int = int(iso_meta.base_padding)
	var w: int = int(iso_meta.map_width) + padding * 2
	var h: int = int(iso_meta.map_height) + padding * 2
	var offset_x: int = int(-w / 2.0)
	var offset_y: int = int(-h / 2.0)
	for wy in h:
		for wx in w:
			base_layer.set_cell(
				Vector2i(wx + offset_x, wy + offset_y),
				SRC_ORIGINAL,
				Vector2i(TILE_BASE_MAGENTA, 0)
			)


func _populate_ground_with_grass_covering_all() -> void:
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	for wy in h:
		for wx in w:
			ground_layer.set_cell(Vector2i(wx, wy), SRC_ORIGINAL, Vector2i(TILE_GRASS, 0))


func _carve_horizontal_path_original() -> void:
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	var path_y: int = int(h * float(iso_meta.path_start_y_ratio))
	for x in w:
		var tile_id: int = TILE_PATH_YELLOW if x % 2 == 0 else TILE_PATH_ORANGE
		ground_layer.set_cell(Vector2i(x, path_y), SRC_ORIGINAL, Vector2i(tile_id, 0))


func _populate_decoration_original() -> void:
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	var positions: Array[Vector2i] = [
		Vector2i(4, 4), Vector2i(8, 6), Vector2i(20, 4), Vector2i(22, 16),
		Vector2i(12, 12), Vector2i(3, 16), Vector2i(16, 18), Vector2i(10, 8),
	]
	var deco_ids: PackedInt32Array = iso_meta.decoration_tile_ids
	if deco_ids.is_empty():
		return
	var idx: int = 0
	for pos in positions:
		var tile_id: int = deco_ids[idx % deco_ids.size()]
		idx += 1
		decoration_layer.set_cell(pos, SRC_ORIGINAL, Vector2i(tile_id, 0))


# ============================================================
# Water + forest (extended layer)
# ============================================================
func _paint_lakes_extended() -> void:
	var lakes: Array = iso_meta.get("lakes") if iso_meta.get("lakes") != null else []
	for entry in lakes:
		if not entry is Dictionary:
			continue
		var rect: Rect2i = entry.get("rect", Rect2i(0, 0, 0, 0))
		_paint_water_rect_extended(rect)


func _paint_water_rect_extended(rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	for wy in rect.size.y:
		for wx in rect.size.x:
			var pos := rect.position + Vector2i(wx, wy)
			ground_layer.set_cell(pos, SRC_EXTENDED, Vector2i(2, 3))


func _paint_forest_patches_extended() -> void:
	var patches: Array = iso_meta.get("forest_patches") if iso_meta.get("forest_patches") != null else []
	for entry in patches:
		if not entry is Dictionary:
			continue
		var center: Vector2i = Vector2i(int(entry.get("center", Vector2(0, 0)).x), int(entry.get("center", Vector2(0, 0)).y))
		var radius: int = int(entry.get("radius", 2))
		var density: float = float(entry.get("density", 0.5))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var pos := center + Vector2i(dx, dy)
				if dx * dx + dy * dy > radius * radius:
					continue
				if randf() > density:
					continue
				ground_layer.set_cell(pos, SRC_EXTENDED, Vector2i(0, 7))


# ============================================================
# Walls (from wall_regions)
# ============================================================
func _populate_walls_from_regions() -> void:
	var regions: Array = iso_meta.get("wall_regions") if iso_meta.get("wall_regions") != null else []
	for entry in regions:
		if not entry is Dictionary:
			continue
		var rect: Rect2i = entry.get("rect", Rect2i(0, 0, 0, 0))
		var material: String = String(entry.get("material", "brick"))
		_paint_wall_region(rect, material)


func _paint_wall_region(rect: Rect2i, material: String) -> void:
	## Paints a rectangular room enclosed by walls (perimeter only).
	## Interior cells are left alone (they keep whatever Ground painted).
	if rect.size.x <= 1 or rect.size.y <= 1:
		return
	var door_positions: Dictionary = _collect_doors_for_region(rect)

	# Top row (north wall)
	for x in range(rect.position.x, rect.end.x + 1):
		var pos := Vector2i(x, rect.position.y)
		if door_positions.has(pos) and door_positions[pos] == "north":
			continue
		walls_layer.set_cell(pos, SRC_WALLS, _wall_tile_for(material, "N"))

	# Bottom row (south wall)
	for x in range(rect.position.x, rect.end.x + 1):
		var pos := Vector2i(x, rect.end.y)
		if door_positions.has(pos) and door_positions[pos] == "south":
			continue
		walls_layer.set_cell(pos, SRC_WALLS, _wall_tile_for(material, "S"))

	# Left col (west wall)
	for y in range(rect.position.y, rect.end.y + 1):
		var pos := Vector2i(rect.position.x, y)
		if door_positions.has(pos) and door_positions[pos] == "west":
			continue
		walls_layer.set_cell(pos, SRC_WALLS, _wall_tile_for(material, "W"))

	# Right col (east wall)
	for y in range(rect.position.y, rect.end.y + 1):
		var pos := Vector2i(rect.end.x, y)
		if door_positions.has(pos) and door_positions[pos] == "east":
			continue
		walls_layer.set_cell(pos, SRC_WALLS, _wall_tile_for(material, "E"))

	# Corners
	walls_layer.set_cell(rect.position, SRC_WALLS, _wall_corner(material, "NW"))
	walls_layer.set_cell(Vector2i(rect.end.x, rect.position.y), SRC_WALLS, _wall_corner(material, "NE"))
	walls_layer.set_cell(Vector2i(rect.position.x, rect.end.y), SRC_WALLS, _wall_corner(material, "SW"))
	walls_layer.set_cell(rect.end, SRC_WALLS, _wall_corner(material, "SE"))


func _collect_doors_for_region(rect: Rect2i) -> Dictionary:
	## Returns dict: { Vector2i pos : String direction } for doors in this region's perimeter.
	var doors_per_region: Array = iso_meta.get("doors") if iso_meta.get("doors") != null else []
	var result: Dictionary = {}
	for door in doors_per_region:
		if not door is Dictionary:
			continue
		var dpos: Vector2i = Vector2i(int(door.get("pos", Vector2(0, 0)).x), int(door.get("pos", Vector2(0, 0)).y))
		var direction: String = String(door.get("opens_to", ""))
		# Only include doors that lie on this region's perimeter.
		var on_perimeter: bool = (
			(dpos.y == rect.position.y or dpos.y == rect.end.y) and
			rect.position.x <= dpos.x and dpos.x <= rect.end.x
		) or (
			(dpos.x == rect.position.x or dpos.x == rect.end.x) and
			rect.position.y <= dpos.y and dpos.y <= rect.end.y
		)
		if on_perimeter:
			result[dpos] = direction
	return result


func _wall_tile_for(material: String, side: String) -> Vector2i:
	if material == "stone":
		match side:
			"N": return _IsoTileCoordsScript.STONE_WALL_BOT_N
			"E": return _IsoTileCoordsScript.STONE_WALL_BOT_E
			"S": return _IsoTileCoordsScript.STONE_WALL_BOT_S
			"W": return _IsoTileCoordsScript.STONE_WALL_BOT_W
	# Default brick
	match side:
		"N": return _IsoTileCoordsScript.BRICK_WALL_BOT_N
		"E": return _IsoTileCoordsScript.BRICK_WALL_BOT_E
		"S": return _IsoTileCoordsScript.BRICK_WALL_BOT_S
		"W": return _IsoTileCoordsScript.BRICK_WALL_BOT_W
	return _IsoTileCoordsScript.BRICK_WALL_BOT_N


func _wall_corner(material: String, corner: String) -> Vector2i:
	if material == "stone":
		match corner:
			"NE": return _IsoTileCoordsScript.STONE_CORNER_NE
			"NW": return _IsoTileCoordsScript.STONE_CORNER_NW
			"SE": return _IsoTileCoordsScript.STONE_CORNER_SE
			"SW": return _IsoTileCoordsScript.STONE_CORNER_SW
	match corner:
		"NE": return _IsoTileCoordsScript.BRICK_CORNER_NE
		"NW": return _IsoTileCoordsScript.BRICK_CORNER_NW
		"SE": return _IsoTileCoordsScript.BRICK_CORNER_SE
		"SW": return _IsoTileCoordsScript.BRICK_CORNER_SW
	return _IsoTileCoordsScript.BRICK_CORNER_NE


# ============================================================
# Doors (placed AFTER walls, on top of the wall cells)
# ============================================================
func _populate_doors() -> void:
	var doors_per_region: Array = iso_meta.get("doors") if iso_meta.get("doors") != null else []
	for door in doors_per_region:
		if not door is Dictionary:
			continue
		var pos: Vector2i = Vector2i(int(door.get("pos", Vector2(0, 0)).x), int(door.get("pos", Vector2(0, 0)).y))
		walls_layer.set_cell(pos, SRC_WALLS, _IsoTileCoordsScript.DOOR_CLOSED)


# ============================================================
# Interior floors + decor
# ============================================================
func _populate_interior_floors() -> void:
	var regions: Array = iso_meta.get("wall_regions") if iso_meta.get("wall_regions") != null else []
	for entry in regions:
		if not entry is Dictionary:
			continue
		var rect: Rect2i = entry.get("rect", Rect2i(0, 0, 0, 0))
		var floor: String = String(entry.get("interior_floor", ""))
		var floor_tile: Vector2i = _floor_tile_for(floor)
		if floor_tile == Vector2i(-1, -1):
			continue
		# Interior cells only (skip perimeter)
		for wy in range(rect.position.y + 1, rect.end.y):
			for wx in range(rect.position.x + 1, rect.end.x):
				ground_layer.set_cell(Vector2i(wx, wy), SRC_EXTENDED, floor_tile)


func _floor_tile_for(floor: String) -> Vector2i:
	match floor:
		"stone": return Vector2i(0, 0)   # decor row 0 = stone
		"wood": return Vector2i(1, 0)
		"carpet": return Vector2i(2, 0)
		"cracked": return Vector2i(3, 0)
		"marble": return Vector2i(4, 0)
		"grass": return Vector2i(5, 0)
		"": return Vector2i(-1, -1)
	return Vector2i(-1, -1)


func _populate_decor_items() -> void:
	var items: Array = iso_meta.get("decor_positions") if iso_meta.get("decor_positions") != null else []
	for entry in items:
		if not entry is Dictionary:
			continue
		var pos: Vector2i = Vector2i(int(entry.get("pos", Vector2(0, 0)).x), int(entry.get("pos", Vector2(0, 0)).y))
		var decor: String = String(entry.get("decor", ""))
		var tile: Vector2i = _decor_tile_for(decor)
		if tile == Vector2i(-1, -1):
			continue
		decor_layer.set_cell(pos, SRC_DECOR, tile)


func _decor_tile_for(decor: String) -> Vector2i:
	match decor:
		"altar": return _IsoTileCoordsScript.ALTAR
		"chest_closed": return _IsoTileCoordsScript.CHEST_CLOSED
		"chest_open": return _IsoTileCoordsScript.CHEST_OPEN
		"door_closed": return _IsoTileCoordsScript.DOOR_CLOSED
		"door_open": return _IsoTileCoordsScript.DOOR_OPEN
		"well": return Vector2i(3, 2)
		"torch": return Vector2i(3, 1)
		"barrel": return Vector2i(4, 2)
		"anvil": return Vector2i(5, 2)
		"sign": return Vector2i(4, 1)
		"banner": return Vector2i(5, 1)
	return Vector2i(-1, -1)


# ============================================================
# Props (trees, rocks — no collision)
# ============================================================
func _populate_props() -> void:
	var props: Array = iso_meta.get("prop_positions") if iso_meta.get("prop_positions") != null else []
	for entry in props:
		if not entry is Dictionary:
			continue
		var pos: Vector2i = Vector2i(int(entry.get("pos", Vector2(0, 0)).x), int(entry.get("pos", Vector2(0, 0)).y))
		var prop: String = String(entry.get("prop", "tree"))
		var tile: Vector2i = _prop_tile_for(prop)
		if tile == Vector2i(-1, -1):
			continue
		props_layer.set_cell(pos, SRC_PROPS, tile)


func _prop_tile_for(prop: String) -> Vector2i:
	match prop:
		"tree": return Vector2i(0, 0)
		"pine": return Vector2i(1, 0)
		"oak": return Vector2i(2, 0)
		"dead_tree": return Vector2i(3, 0)
		"bush": return Vector2i(4, 0)
		"flower_pink": return Vector2i(5, 0)
		"flower_red": return Vector2i(6, 0)
		"rock_small": return Vector2i(0, 1)
		"rock_large": return Vector2i(1, 1)
		"rock_cluster": return Vector2i(2, 1)
		"rock_boulder": return Vector2i(3, 1)
		"mushroom": return Vector2i(4, 1)
	return Vector2i(-1, -1)


# ============================================================
# µFantasy overlay (optional, kept from prior version)
# ============================================================
func _paint_with_microfantasy() -> void:
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	var mf_w: int = int(ceil(w / 3.0))
	var mf_h: int = int(ceil(h / 3.0))
	for wy in mf_h:
		for wx in mf_w:
			microfantasy_layer.set_cell(
				Vector2i(wx, wy),
				0,
				Vector2i(wx % 18, MF_TILE_GRASS_ROW)
			)
	var path_y: int = int(mf_h * float(iso_meta.path_start_y_ratio))
	for wx in mf_w:
		microfantasy_layer.set_cell(
			Vector2i(wx, path_y),
			0,
			Vector2i(wx % 18, MF_TILE_PATH_ROW)
		)


# ============================================================
# Player + enemies
# ============================================================
func _spawn_enemies() -> void:
	var spawns: Array[Vector2i] = iso_meta.enemy_spawns
	var enemy_data_list: Array[Dictionary] = iso_meta.enemy_data
	for i in spawns.size():
		var tile_pos: Vector2i = spawns[i]
		var data: Dictionary = enemy_data_list[i % enemy_data_list.size()]
		var enemy: Area2D = _IsoEnemyScene.instantiate() as Area2D
		if enemy == null:
			push_warning("IsoDemoWorld: failed to instantiate iso_enemy.tscn")
			continue
		enemy.tile_position = tile_pos
		enemy.display_name = String(data.get("display_name", "Enemy"))
		enemy.max_hp = int(data.get("max_hp", 50))
		enemy.challenge_id = String(data.get("challenge_id", "main_exit_check"))
		enemies_container.add_child(enemy)


func _position_player() -> void:
	if player_spawn and player:
		player.global_position = player_spawn.global_position
