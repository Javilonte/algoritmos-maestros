class_name IsoMeta extends Resource

# Map dimensions in tile units.
@export var map_width: int = 50
@export var map_height: int = 40

# Visual / gameplay seed
@warning_ignore("shadowed_global_identifier")
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

# === Extended terrain (autotile-ready) ===
# Lake regions placed on the ground as water tiles. Each entry is a Rect2i in tile coords:
# { "rect": Rect2i(x, y, w, h), "border": "sand" }
# Wood/forest patches now use true tree props (decoration layer).
@export var lakes: Array[Dictionary] = [
	{ "rect": Rect2i(20, 8, 4, 3), "border": "sand" },
]

# Forest patches now use tree prop tiles from the extended atlas (row 7).
# Each entry is { "center": Vector2i, "radius": int, "density": float (0.0-1.0) }.
@export var forest_patches: Array[Dictionary] = [
	{ "center": Vector2i(6, 16), "radius": 2, "density": 0.7 },
]

# Enable/Disable the entire extended terrain pipeline.
@export var use_extended_terrain: bool = true
@export var water_tile: Vector2i = Vector2i(0, 3)   # col=0, row=3 (water inner)
@export var sand_tile: Vector2i = Vector2i(0, 2)    # col=0, row=2 (sand inner)
@export var grass_tile: Vector2i = Vector2i(0, 4)   # col=0, row=4 (grass inner)
@export var tree_prop_tile: Vector2i = Vector2i(0, 7)
@export var rock_prop_tile: Vector2i = Vector2i(1, 7)
@export var bush_prop_tile: Vector2i = Vector2i(2, 7)

# === Walls + interiors ===
# Each region defines a rectangular room enclosed by walls. Doors on the perimeter
# are specified separately so the wall painter can leave a gap.
#
# Schema for wall_regions entry:
#   {
#     "rect": Rect2i(x, y, w, h),   # tile coords; interior cells filled with ground
#     "material": "brick" | "stone" # wall style (determines atlas row to use)
#     "interior_floor": "stone" | "wood" | "carpet" | null  # decor floor style
#   }
@export var wall_regions: Array[Dictionary] = [
	{ "rect": Rect2i(4, 4, 6, 4), "material": "brick", "interior_floor": "stone" },
	{ "rect": Rect2i(14, 4, 5, 5), "material": "stone", "interior_floor": "carpet" },
	{ "rect": Rect2i(4, 12, 8, 6), "material": "brick", "interior_floor": "wood" },
]

# Door positions in tile coords. Each door "opens" a wall in the wall_regions perimeter.
# Schema: { "pos": Vector2i, "opens_to": "south" | "north" | "east" | "west" }
@export var doors: Array[Dictionary] = [
	{ "pos": Vector2i(7, 8), "opens_to": "south" },
	{ "pos": Vector2i(16, 4), "opens_to": "north" },
	{ "pos": Vector2i(8, 12), "opens_to": "north" },
	{ "pos": Vector2i(11, 18), "opens_to": "south" },
]

# Decor positions: things inside rooms (chests, altars).
# Schema: { "pos": Vector2i, "decor": "chest_closed" | "chest_open" | "altar" | "door_closed" | "door_open" | "well" | "torch" }
@export var decor_positions: Array[Dictionary] = [
	{ "pos": Vector2i(6, 6), "decor": "chest_closed" },
	{ "pos": Vector2i(8, 6), "decor": "altar" },
	{ "pos": Vector2i(16, 6), "decor": "well" },
	{ "pos": Vector2i(17, 7), "decor": "torch" },
	{ "pos": Vector2i(7, 15), "decor": "chest_closed" },
	{ "pos": Vector2i(10, 17), "decor": "altar" },
]

# Decorative props scattered around the world (no collision): trees, rocks, bushes.
# These are placed OUTSIDE wall_regions (in the open grass).
# Schema: { "pos": Vector2i, "prop": "tree" | "rock" | "bush" }
@export var prop_positions: Array[Dictionary] = [
	{ "pos": Vector2i(22, 8), "prop": "tree" },
	{ "pos": Vector2i(23, 9), "prop": "tree" },
	{ "pos": Vector2i(12, 1), "prop": "rock" },
	{ "pos": Vector2i(20, 14), "prop": "tree" },
	{ "pos": Vector2i(22, 16), "prop": "bush" },
	{ "pos": Vector2i(2, 19), "prop": "rock" },
]	