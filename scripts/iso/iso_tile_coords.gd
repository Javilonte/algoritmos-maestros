class_name IsoTileCoords
extends RefCounted

## Centralized tile coordinate constants for all iso tile atlases.
## Each atlas uses a (col, row) convention where col=x is horizontal offset and
## row=y is vertical offset. Coordinates are within the TileSetAtlasSource.
##
## Wall atlas (350x504 = 7 cols × 9 rows × 50x56):
##   Row 0: 1-tile brick wall tops (lit faces for cardinal walls N/E/S/W)
##   Row 1: brick wall sides (shadow faces for cardinal walls)
##   Row 2: brick corners (NE/NW/SE/SW)
##   Row 3: brick column (1x1 pillar)
##   Row 4: 2-tile-height top wall corners
##   Row 5: 1-tile stone wall tops
##   Row 6: stone wall sides
##   Row 7: stone corners
##   Row 8: stone column

const _INVALID: Vector2i = Vector2i(-1, -1)

# Brick walls
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

# Stone walls
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

# Decor atlas (350x336 = 7 cols × 6 rows × 50x56):
#   Row 0: floor variants (stone, wood, carpet, cracked)
#   Row 1: altar, chest_closed, chest_open
#   Row 2: door_closed, door_open, stairs_up
#   Row 3: well, bookshelf, anvil
#   Row 4: torch, sign, banner
#   Row 5: reserved (placeholder marker)

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
