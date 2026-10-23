class_name IsoTileCoords
extends RefCounted

## Single source of truth for **tile coordinates** across all iso atlases.
##
## Two tiers:
##   1. Functional names (the public API): FLOOR_PLAIN, WALL_BRICK_N, etc.
##      Callers should always use these — never raw coordinates.
##   2. Atlas-coord aliases (private): the actual `(col, row)` position in
##      each atlas. Aliases are exposed only to the QA pipeline / atlas
##      regenerators; gameplay code stays on the functional names.
##
## Conventions shared by all atlases below:
##   - Each tile is a 50x56 iso diamond (microfantasy uses 16x8).
##   - Coordinates are `(col, row)` inside the TileSetAtlasSource.
##   - Functional category order in each atlas:
##       FLOOR → EDGE → WALL → ACCESS (door) → STRUCTURE → PROP → UNUSED
##     New tiles MUST be appended; existing positions MUST stay locked.
##
## Atlas inventory (locked by QA tests):
##   - ORIGINAL (350x112 = 7 cols × 2 rows × 50x56):
##       practice_iso_tiles_original.png (legacy colored squares + teal player)
##   - EXTENDED (350x784 = 7 cols × 14 rows × 50x56):
##       iso_terrain_atlas.png (procedural sand/grass/water + props)
##   - WALLS (350x504 = 7 cols × 9 rows × 50x56):
##       iso_walls_atlas.png (brick + stone wall variants)
##   - DECOR (350x336 = 7 cols × 6 rows × 50x56):
##       iso_decor_atlas.png (floor + furniture + doors)
##   - PROPS (350x280 = 7 cols × 5 rows × 50x56):
##       iso_props_atlas.png (tree/rock/bush scattered decor)
##   - CYBERPUNK_FLOORS (1024x256 = 4 cols × 2 rows × 256x128):
##       tilemap_cyberpunk_floors.png (8 floor variants)
##   - MICROFANTASY (288x160 = 18 cols × 20 rows × 16x8):
##       external/microfantasy/iso/iso_tileset.png (CC0 0x72)

const _INVALID: Vector2i = Vector2i(-1, -1)

# ============================================================================
# CYBERPUNK atlas (256x128 cells, 4x2 grid) — the playable map MVP.
# Layout (verified against tilemap_cyberpunk_floors.png):
#   (0,0) plain stone        (1,0) rubble
#   (2,0) broken pipe L      (3,0) broken pipe R
#   (0,1) broken earth       (1,1) interior corner wall
#   (2,1) cracked + toxic    (3,1) destroyed slab
# Existing semantic names preserved so callers don't break.
# ============================================================================
const CYBER_FLOOR_PLAIN: Vector2i = Vector2i(0, 0)
const CYBER_FLOOR_RUBBLE: Vector2i = Vector2i(1, 0)
const CYBER_FLOOR_PIPE_L: Vector2i = Vector2i(2, 0)
const CYBER_FLOOR_PIPE_R: Vector2i = Vector2i(3, 0)
const CYBER_FLOOR_BROKEN_EARTH: Vector2i = Vector2i(0, 1)
const CYBER_CORNER_WALL: Vector2i = Vector2i(1, 1)
const CYBER_FLOOR_CRACKED_TOXIC: Vector2i = Vector2i(2, 1)
const CYBER_FLOOR_DESTROYED: Vector2i = Vector2i(3, 1)

# Kept for backwards compatibility with the QA render's old (incorrect)
# names. These aliases let the playable demo's callers migrate to the
# semantic names without breaking the QA render in the same commit.
const CYBER_FLOOR_BROKEN_E: Vector2i = CYBER_FLOOR_PIPE_L
const CYBER_FLOOR_BROKEN_C: Vector2i = CYBER_FLOOR_PIPE_R
const CYBER_FLOOR_MARKED_NE: Vector2i = CYBER_FLOOR_PLAIN
const CYBER_FLOOR_MARKED_SW: Vector2i = CYBER_FLOOR_RUBBLE
const CYBER_FLOOR_DESTROYED_L: Vector2i = CYBER_FLOOR_BROKEN_EARTH
const CYBER_FLOOR_DESTROYED_R: Vector2i = CYBER_CORNER_WALL
const CYBER_FLOOR_GRATE_L: Vector2i = CYBER_FLOOR_CRACKED_TOXIC
const CYBER_FLOOR_GRATE_R: Vector2i = CYBER_FLOOR_DESTROYED
const CYBER_TOXIC_POOL: Vector2i = CYBER_FLOOR_CRACKED_TOXIC

## Returns the cyberpunk floor tile for a given world hex.
## Mirrors the playable demo's original `_pick_tile` heuristic:
##   - center plain       (max_d == 0)
##   - ring 1 rubble/pipe (max_d == 1)
##   - ring 2 broken      (max_d == 2)
##   - ring 3 destroyed   (max_d == 3)
##   - outer ring toxic   (max_d >= 4)
## The QA render uses `center=(4,4)` to anchor on its 9x9 grid; the playable
## demo uses the default `center=(0,0)`.
static func cyber_floor_for(gx: int, gy: int, center: Vector2i = Vector2i(0, 0)) -> Vector2i:
	var dx: int = abs(gx - center.x)
	var dy: int = abs(gy - center.y)
	var max_d: int = max(dx, dy)
	var parity: int = (gx + gy) % 2
	if max_d == 0:
		return CYBER_FLOOR_PLAIN
	if max_d == 1:
		return CYBER_FLOOR_PLAIN if parity == 0 else CYBER_FLOOR_RUBBLE
	if max_d == 2:
		return CYBER_FLOOR_PIPE_L if parity == 0 else CYBER_FLOOR_PIPE_R
	if max_d == 3:
		return CYBER_FLOOR_BROKEN_EARTH if parity == 0 else CYBER_CORNER_WALL
	# max_d >= 4 (outer ring) — cracked/destroyed.
	return CYBER_FLOOR_CRACKED_TOXIC if parity == 0 else CYBER_FLOOR_DESTROYED

# ============================================================================
# ORIGINAL atlas (50x56, 7x2 grid) — legacy colored squares + player teal.
# ============================================================================
# Row 0: bright color squares (grass/dirt field palette).
const ORIG_BLUE: Vector2i = Vector2i(0, 0)
const ORIG_GREEN_LIGHT: Vector2i = Vector2i(1, 0)
const ORIG_GREEN: Vector2i = Vector2i(2, 0)
const ORIG_YELLOW: Vector2i = Vector2i(3, 0)
const ORIG_ORANGE: Vector2i = Vector2i(4, 0)
const ORIG_BROWN: Vector2i = Vector2i(5, 0)
const ORIG_DARK_BROWN: Vector2i = Vector2i(6, 0)
# Row 1: accent + decoration.
const ORIG_GREY: Vector2i = Vector2i(0, 1)
const ORIG_RED: Vector2i = Vector2i(1, 1)
const ORIG_TEAL: Vector2i = Vector2i(2, 1)        # player sprite frame
const ORIG_PINK: Vector2i = Vector2i(3, 1)
const ORIG_DARK_GREY: Vector2i = Vector2i(4, 1)
const ORIG_MAGENTA: Vector2i = Vector2i(5, 1)
const ORIG_MED_GREY: Vector2i = Vector2i(6, 1)

# ============================================================================
# EXTENDED atlas (50x56, 7x14 grid) — procedural sand/grass/water + props.
# ============================================================================
# Row 2: sand (inner).
const EXT_SAND: Vector2i = Vector2i(0, 2)
# Row 3: water (inner). Row 6 = water with foam markers.
const EXT_WATER: Vector2i = Vector2i(0, 3)
const EXT_WATER_FOAM: Vector2i = Vector2i(0, 6)
# Rows 4 & 5: grass (inner) — duplicated so biome graphs can pick a variant.
const EXT_GRASS: Vector2i = Vector2i(0, 4)
const EXT_GRASS_VAR: Vector2i = Vector2i(0, 5)
# Row 7: scattered props by column.
const EXT_PROP_TREE: Vector2i = Vector2i(0, 7)
const EXT_PROP_ROCK: Vector2i = Vector2i(1, 7)
const EXT_PROP_BUSH: Vector2i = Vector2i(2, 7)
const EXT_PROP_FLOWER_RED: Vector2i = Vector2i(3, 7)
const EXT_PROP_FLOWER_YELLOW: Vector2i = Vector2i(4, 7)
const EXT_PROP_FLOWER_PURPLE: Vector2i = Vector2i(5, 7)
const EXT_PROP_ROCK_VAR: Vector2i = Vector2i(6, 7)

# ============================================================================
# WALLS atlas (50x56, 7x9 grid) — brick + stone wall variants.
# Row 0: 1-tile brick wall tops (lit faces for cardinal walls N/E/S/W)
# Row 1: brick wall sides (shadow faces for cardinal walls)
# Row 2: brick corners (NE/NW/SE/SW)
# Row 3: brick column (1x1 pillar)
# Row 4: 2-tile-height top wall corners
# Row 5: 1-tile stone wall tops
# Row 6: stone wall sides
# Row 7: stone corners
# Row 8: stone column
# ============================================================================
const BRICK_WALL_N: Vector2i = Vector2i(0, 0)
const BRICK_WALL_E: Vector2i = Vector2i(1, 0)
const BRICK_WALL_S: Vector2i = Vector2i(2, 0)
const BRICK_WALL_W: Vector2i = Vector2i(3, 0)
const BRICK_WALL_BOT_N: Vector2i = Vector2i(0, 1)
const BRICK_WALL_BOT_E: Vector2i = Vector2i(1, 1)
const BRICK_WALL_BOT_S: Vector2i = Vector2i(2, 1)
const BRICK_WALL_BOT_W: Vector2i = Vector2i(3, 1)
const BRICK_CORNER_NE: Vector2i = Vector2i(0, 2)
const BRICK_CORNER_NW: Vector2i = Vector2i(1, 2)
const BRICK_CORNER_SE: Vector2i = Vector2i(2, 2)
const BRICK_CORNER_SW: Vector2i = Vector2i(3, 2)
const BRICK_COLUMN: Vector2i = Vector2i(4, 2)

const STONE_WALL_N: Vector2i = Vector2i(0, 5)
const STONE_WALL_E: Vector2i = Vector2i(1, 5)
const STONE_WALL_S: Vector2i = Vector2i(2, 5)
const STONE_WALL_W: Vector2i = Vector2i(3, 5)
const STONE_WALL_BOT_N: Vector2i = Vector2i(0, 6)
const STONE_WALL_BOT_E: Vector2i = Vector2i(1, 6)
const STONE_WALL_BOT_S: Vector2i = Vector2i(2, 6)
const STONE_WALL_BOT_W: Vector2i = Vector2i(3, 6)
const STONE_CORNER_NE: Vector2i = Vector2i(0, 7)
const STONE_CORNER_NW: Vector2i = Vector2i(1, 7)
const STONE_CORNER_SE: Vector2i = Vector2i(2, 7)
const STONE_CORNER_SW: Vector2i = Vector2i(3, 7)
const STONE_COLUMN: Vector2i = Vector2i(4, 7)

# ============================================================================
# DECOR atlas (50x56, 7x6 grid) — floor + furniture + doors.
# Row 0: floor variants (stone, wood, carpet, cracked)
# Row 1: altar, chest_closed, chest_open
# Row 2: door_closed, door_open, stairs_up
# Row 3: well, bookshelf, anvil
# Row 4: torch, sign, banner
# Row 5: reserved (placeholder marker)
# ============================================================================
const FLOOR_STONE: Vector2i = Vector2i(0, 0)
const FLOOR_WOOD: Vector2i = Vector2i(1, 0)
const FLOOR_CARPET: Vector2i = Vector2i(2, 0)
const FLOOR_CRACKED: Vector2i = Vector2i(3, 0)
const ALTAR: Vector2i = Vector2i(0, 1)
const CHEST_CLOSED: Vector2i = Vector2i(1, 1)
const CHEST_OPEN: Vector2i = Vector2i(2, 1)
const DOOR_CLOSED: Vector2i = Vector2i(0, 2)
const DOOR_OPEN: Vector2i = Vector2i(1, 2)
const STAIRS_UP: Vector2i = Vector2i(2, 2)


## Returns true if the given tile coord is one of the known wall variants.
static func is_wall_tile(coord: Vector2i) -> bool:
	if coord == _INVALID:
		return false
	if coord.y < 0 or coord.y > 8:
		return false
	# Walls are in rows 0-2 (brick) and 5-7 (stone), plus column row 4 (top walls).
	if coord.y in [0, 1, 2, 4, 5, 6, 7]:
		return coord.x >= 0 and coord.x <= 6
	return false


## Returns true if the given tile coord is a closed door (collidable).
static func is_door_closed(coord: Vector2i) -> bool:
	return coord == DOOR_CLOSED


## Returns the material ("brick" or "stone") for a given wall coord.
static func wall_material(coord: Vector2i) -> String:
	if coord.y in [0, 1, 2, 4]:
		return "brick"
	if coord.y in [5, 6, 7]:
		return "stone"
	return "unknown"


## Returns the floor variant for a given interior ("stone" | "wood" | "carpet" | null).
static func floor_for_interior(material: String) -> Vector2i:
	match material:
		"stone": return FLOOR_STONE
		"wood": return FLOOR_WOOD
		"carpet": return FLOOR_CARPET
		_:
			return _INVALID


## Returns the prop tile coord for a named prop ("tree" | "rock" | "bush").
## Falls back to the original atlas (legacy column 2 row 1) for backwards
## compatibility with iso_meta.gd entries that predate the EXT atlas.
static func prop_for(name: StringName) -> Vector2i:
	match name:
		&"tree": return EXT_PROP_TREE
		&"rock": return EXT_PROP_ROCK
		&"bush": return EXT_PROP_BUSH
	return _INVALID
