extends Node2D

const TILEMAP_LAYER_GROUND := "Ground"
const TILEMAP_LAYER_DECORATION := "Decoration"

@onready var base_layer: TileMapLayer = $TileMapLayers/Base
@onready var ground_layer: TileMapLayer = $TileMapLayers/Ground
@onready var decoration_layer: TileMapLayer = $TileMapLayers/Decoration
@onready var enemies_container: Node2D = $Enemies
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var iso_camera: Camera2D = $IsoCamera
@onready var player: CharacterBody2D = $IsoPlayer

@export var iso_meta: Resource

var _biome_centers: Array[Vector2i] = []
var _building_centers: Array[Vector2i] = []

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	if iso_meta == null:
		push_error("IsoWorld: iso_meta not assigned")
		return
	if bool(iso_meta.base_enabled):
		_populate_base()
	_populate_ground()
	if bool(iso_meta.biomes_enabled):
		_generate_biomes()
	if bool(iso_meta.path_enabled):
		_carve_path()
	if bool(iso_meta.buildings_enabled):
		_populate_buildings()
	_populate_decoration()
	_spawn_enemies()
	_position_player()
	EventBus.player_spawned.emit(player)

func _populate_base() -> void:
	var padding: int = int(iso_meta.base_padding)
	var w: int = int(iso_meta.map_width) + padding * 2
	var h: int = int(iso_meta.map_height) + padding * 2
	var offset_x: int = int(-w / 2.0)
	var offset_y: int = int(-h / 2.0)
	var base_id: int = int(iso_meta.base_tile_id)
	for wy in h:
		for wx in w:
			base_layer.set_cell(Vector2i(wx + offset_x, wy + offset_y), 0, Vector2i(base_id, 0))

func _populate_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(iso_meta.seed)
	var ground_ids: PackedInt32Array = iso_meta.ground_tile_ids
	if ground_ids.is_empty():
		push_error("IsoWorld: iso_meta.ground_tile_ids is empty")
		return
	for wy in int(iso_meta.map_height):
		for wx in int(iso_meta.map_width):
			var tile_id: int = ground_ids[rng.randi_range(0, ground_ids.size() - 1)]
			ground_layer.set_cell(Vector2i(wx, wy), 0, Vector2i(tile_id, 0))

func _generate_biomes() -> void:
	# Place biome "centers" across the map and grow tiles around them.
	# Each entry in iso_meta.biomes is {tile_id, count, radius}.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(iso_meta.seed) + 21
	var biomes: Array = iso_meta.biomes
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	for biome in biomes:
		var tile_id: int = int(biome.get("tile_id", 1))
		var count: int = int(biome.get("count", 0))
		var radius: int = int(biome.get("radius", 2))
		for i in count:
			var cx: int = rng.randi_range(radius, w - radius - 1)
			var cy: int = rng.randi_range(radius, h - radius - 1)
			_grow_biome_blob(Vector2i(cx, cy), tile_id, radius, rng)

func _grow_biome_blob(center: Vector2i, tile_id: int, radius: int, rng: RandomNumberGenerator) -> void:
	# Place a roughly circular cluster of tiles around the center.
	# Uses diamond-walk expansion for organic shape.
	var tiles_to_place: Array[Vector2i] = [center]
	var placed: Dictionary = {center: true}
	ground_layer.set_cell(center, 0, Vector2i(tile_id, 0))
	var target_count: int = max(2, int(radius * radius / 2.0))
	var attempts := 0
	while tiles_to_place.size() < target_count and attempts < target_count * 4:
		attempts += 1
		var seed_pos: Vector2i = tiles_to_place[rng.randi() % tiles_to_place.size()]
		var directions: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
		]
		var dir: Vector2i = directions[rng.randi() % directions.size()]
		var new_pos: Vector2i = seed_pos + dir
		if abs(new_pos.x - center.x) > radius or abs(new_pos.y - center.y) > radius:
			continue
		if placed.has(new_pos):
			continue
		placed[new_pos] = true
		tiles_to_place.append(new_pos)
		ground_layer.set_cell(new_pos, 0, Vector2i(tile_id, 0))

func _carve_path() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(iso_meta.seed) + 7
	var path_ids: PackedInt32Array = iso_meta.path_tile_ids
	if path_ids.is_empty():
		return
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	var drift: float = float(iso_meta.path_vertical_drift)
	var y: float = h * float(iso_meta.path_start_y_ratio)
	for x in w:
		var noise := rng.randf_range(-drift, drift) * 2.0
		y += noise
		var center_pull := (h * 0.5 - y) * 0.04
		y += center_pull
		y = clamp(y, 1.0, float(h - 2))
		var tile_y: int = int(round(y))
		ground_layer.set_cell(Vector2i(x, tile_y), 0, Vector2i(path_ids[rng.randi_range(0, path_ids.size() - 1)], 0))
		if rng.randf() < 0.3:
			var second_y: int = tile_y + (1 if rng.randf() < 0.5 else -1)
			if second_y >= 0 and second_y < h:
				ground_layer.set_cell(Vector2i(x, second_y), 0, Vector2i(path_ids[rng.randi_range(0, path_ids.size() - 1)], 0))

func _populate_buildings() -> void:
	# Multi-tile clusters of wall-colored tiles (decoration layer).
	var rng := RandomNumberGenerator.new()
	rng.seed = int(iso_meta.seed) + 42
	var building_count: int = int(iso_meta.building_count)
	var building_tiles: PackedInt32Array = iso_meta.building_tile_ids
	if building_tiles.is_empty():
		return
	var size_min: int = int(iso_meta.building_size_range.x)
	var size_max: int = int(iso_meta.building_size_range.y)
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	for i in building_count:
		var bw: int = rng.randi_range(size_min, size_max)
		var bh: int = rng.randi_range(size_min, size_max)
		var bx: int = rng.randi_range(2, w - bw - 2)
		var by: int = rng.randi_range(2, h - bh - 2)
		if _overlaps_path(bx, by, bw, bh) or _overlaps_biomes(bx, by, bw, bh):
			continue
		_building_centers.append(Vector2i(int(bx + bw / 2.0), int(by + bh / 2.0)))
		var base_color: int = building_tiles[rng.randi() % building_tiles.size()]
		for dy in bh:
			for dx in bw:
				var cell: Vector2i = Vector2i(bx + dx, by + dy)
				var tile_id: int = base_color
				decoration_layer.set_cell(cell, 0, Vector2i(tile_id, 0))

func _overlaps_path(_bx: int, by: int, bw: int, bh: int) -> bool:
	if not bool(iso_meta.path_enabled):
		return false
	var h: int = int(iso_meta.map_height)
	var path_y: int = int(h * float(iso_meta.path_start_y_ratio))
	for dy in bh:
		for dx in bw:
			if abs((by + dy) - path_y) <= 1:
				return true
	return false

func _overlaps_biomes(bx: int, by: int, bw: int, bh: int) -> bool:
	for c in _biome_centers:
		if c == Vector2i.ZERO:
			continue
		var min_x: int = min(c.x - 4, bx)
		var max_x: int = max(c.x + 4, bx + bw - 1)
		var min_y: int = min(c.y - 4, by)
		var max_y: int = max(c.y + 4, by + bh - 1)
		if max_x - min_x < (bw + 8) and max_y - min_y < (bh + 8):
			return true
	return false

func _populate_decoration() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(iso_meta.seed) + 13
	var deco_ids: PackedInt32Array = iso_meta.decoration_tile_ids
	if deco_ids.is_empty():
		return
	var w: int = int(iso_meta.map_width)
	var h: int = int(iso_meta.map_height)
	var target_count: int = int(float(w * h) * float(iso_meta.decoration_density) / 100.0)
	var placed := 0
	var attempts := 0
	while placed < target_count and attempts < target_count * 4:
		attempts += 1
		var wx: int = rng.randi_range(0, w - 1)
		var wy: int = rng.randi_range(0, h - 1)
		var ground_id: int = _get_tile_id_at(ground_layer, Vector2i(wx, wy))
		if ground_id != 3 and ground_id != 4 and ground_id != 0:
			if decoration_layer.get_cell_atlas_coords(Vector2i(wx, wy)) == Vector2i(-1, -1):
				decoration_layer.set_cell(Vector2i(wx, wy), 0, Vector2i(deco_ids[rng.randi() % deco_ids.size()], 0))
				placed += 1

func _get_tile_id_at(layer: TileMapLayer, pos: Vector2i) -> int:
	var atlas: Vector2i = layer.get_cell_atlas_coords(pos)
	if atlas == Vector2i(-1, -1):
		return -1
	return atlas.x

func _spawn_enemies() -> void:
	var spawns: Array[Vector2i] = iso_meta.enemy_spawns
	var enemy_data_list: Array[Dictionary] = iso_meta.enemy_data
	for i in spawns.size():
		var tile_pos: Vector2i = spawns[i]
		var data: Dictionary = enemy_data_list[i % enemy_data_list.size()]
		var enemy_scene: PackedScene = load("res://scenes/iso/iso_enemy.tscn")
		var enemy: Area2D = enemy_scene.instantiate() as Area2D
		if enemy == null:
			push_warning("IsoWorld: failed to instantiate iso_enemy.tscn")
			continue
		enemy.tile_position = tile_pos
		enemy.display_name = String(data.get("display_name", "Goblin"))
		enemy.max_hp = int(data.get("max_hp", 100))
		enemy.challenge_id = String(data.get("challenge_id", "main_exit_check"))
		enemies_container.add_child(enemy)

func _position_player() -> void:
	if player_spawn and player:
		player.global_position = player_spawn.global_position