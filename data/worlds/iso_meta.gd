class_name IsoMeta extends Resource

# Map dimensions in tile units.
@export var map_width: int = 50
@export var map_height: int = 40

# Visual / gameplay seed
@export var seed: int = 12345

# Tile IDs from the TileSet atlas (see iso_tileset.tres):
# Top row:    [0] blue  [1] green_light  [2] green   [3] yellow
#             [4] orange [5] brown          [6] dark_brown
# Bottom row: [7] grey  [8] red           [9] teal    [10] pink
#             [11] dark_grey [12] magenta   [13] med_grey
# Plus:        [14] small green bar (decoration only)

# Tiles for grass field (variation between light green and green).
@export var ground_tile_ids: PackedInt32Array = PackedInt32Array([2, 2, 2, 1, 2, 2])
# Tiles for the walking path (yellow → orange, dirt-like).
@export var path_tile_ids: PackedInt32Array = PackedInt32Array([3, 3, 4])
# Tiles for decoration layer (flowers + rocks, placed sparsely).
@export var decoration_tile_ids: PackedInt32Array = PackedInt32Array([10, 13, 12])
# Density: how many decoration cells per 100 map tiles (rough).
@export var decoration_density: float = 2.5

# Base layer: the "world foundation" tile that fills the void beyond the
# playable map. Visible everywhere as the background terrain.
@export var base_tile_id: int = 12  # magenta/purple
@export var base_padding: int = 100  # extra tiles around the playable map
@export var base_enabled: bool = true

# Path generation parameters.
@export var path_enabled: bool = true
@export var path_vertical_drift: float = 0.4
@export var path_start_y_ratio: float = 0.5

# === Biome system ===
# Each biome places a cluster of one tile-type at a center point.
# Random blobs of land use across the playable map.
@export var biomes_enabled: bool = true
@export var biomes: Array[Dictionary] = [
	# Forest patches — brown/dark_brown trees
	{
		"tile_id": 5,
		"count": 4,
		"radius": 3,
	},
	{
		"tile_id": 6,
		"count": 3,
		"radius": 2,
	},
	# Farm fields — yellow/orange crops
	{
		"tile_id": 3,
		"count": 3,
		"radius": 3,
	},
	{
		"tile_id": 4,
		"count": 2,
		"radius": 2,
	},
	# Rocky areas — grey stones
	{
		"tile_id": 7,
		"count": 3,
		"radius": 2,
	},
	{
		"tile_id": 11,
		"count": 2,
		"radius": 2,
	},
	# Water pond — blue
	{
		"tile_id": 0,
		"count": 1,
		"radius": 2,
	},
]

# === Building clusters ===
# Uses decoration layer (above ground, non-blocking visually).
# Each cluster is a 2×2 or 3×3 block of wall-colored tiles.
@export var buildings_enabled: bool = true
@export var building_count: int = 6
@export var building_tile_ids: PackedInt32Array = PackedInt32Array([8, 9, 13, 10, 11])
@export var building_size_range: Vector2i = Vector2i(2, 3)

# Enemy spawn points in tile coords (Vector2i(world_x, world_y)).
@export var enemy_spawns: Array[Vector2i] = [
	Vector2i(8, 8),
	Vector2i(24, 12),
	Vector2i(42, 18),
	Vector2i(15, 28),
	Vector2i(38, 34),
]

# Each spawn is [challenge_id, display_name, max_hp].
@export var enemy_data: Array[Dictionary] = [
	{
		"challenge_id": "main_exit_check",
		"display_name": "Iso Goblin",
		"max_hp": 80,
	},
	{
		"challenge_id": "bubble_sort",
		"display_name": "Sort Wraith",
		"max_hp": 60,
	},
	{
		"challenge_id": "linear_search",
		"display_name": "Linear Lurker",
		"max_hp": 50,
	},
	{
		"challenge_id": "factorial",
		"display_name": "Factorial Wraith",
		"max_hp": 70,
	},
	{
		"challenge_id": "fibonacci",
		"display_name": "Fibonacci Lich",
		"max_hp": 90,
	},
]