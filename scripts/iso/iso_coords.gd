class_name IsoCoords
extends RefCounted

# Conversions for the 50×28 isometric grid (cube visual is 50×56 in source PNG).
# Tile spacing: 50 wide × 28 tall (half the cube height).
# World (wx, wy) maps to screen via:
#   screen_x = (wx - wy) * tile_half_w
#   screen_y = (wx + wy) * tile_half_h

const TILE_W: int = 50
const TILE_H: int = 28
const TILE_HALF_W: float = 25.0
const TILE_HALF_H: float = 14.0

# Convert world (tile) coordinates to screen (pixel) coordinates.
# Returns the CENTER of the diamond top-face in pixels (relative to grid origin).
static func world_to_screen(wx: float, wy: float) -> Vector2:
	return Vector2((wx - wy) * TILE_HALF_W, (wx + wy) * TILE_HALF_H)

# Convert screen (pixel) coordinates to world (tile) coordinates.
# Returns a Vector2 with float values — round if you need an integer tile coord.
static func screen_to_world(sx: float, sy: float) -> Vector2:
	var wx: float = (sx / TILE_W) + (sy / TILE_H)
	var wy: float = (sy / TILE_H) - (sx / TILE_W)
	return Vector2(wx, wy)

# Convert world tile coords to screen with proper z-offset (for objects
# that should sit "on" the tile rather than at its center).
static func world_to_screen_anchored(wx: int, wy: int, anchor_y_offset: float = 0.0) -> Vector2:
	return Vector2(
		(wx - wy) * TILE_HALF_W,
		(wx + wy) * TILE_HALF_H + anchor_y_offset
	)

# Convert input direction (e.g. WASD) into a screen-space velocity vector
# matching the iso projection. Length 1 input → length 1 output.
static func iso_input_to_velocity(input: Vector2) -> Vector2:
	if input.length() < 0.001:
		return Vector2.ZERO
	# Match the world_to_screen projection: dx→screen (dx-dy), dy→screen (dx+dy)
	var iso := Vector2(input.x - input.y, input.x + input.y) * 0.5
	# Convert "tile units" to pixel velocity (multiply by tile size for natural feel).
	var screen_velocity := Vector2(iso.x * TILE_W, iso.y * TILE_H)
	return screen_velocity.normalized()

# Z-index based on world y — used for Y-sorting objects on the iso plane.
# Higher wy = deeper into the map = higher z-index = drawn on top.
static func z_index_for(wx: int, wy: int) -> int:
	return wy * 10 - wx