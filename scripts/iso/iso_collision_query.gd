class_name IsoCollisionQuery
extends RefCounted

## Pure-functional helpers to query iso TileMapLayers for collision info.
## Use this in addition to Godot's built-in physics for defense-in-depth.

const IsoTileCoordsScript = preload("res://scripts/iso/iso_tile_coords.gd")


## True if the given world tile coord has any cell in `layer`.
static func has_cell(layer: TileMapLayer, pos: Vector2i) -> bool:
	if layer == null:
		return false
	return layer.get_cell_source_id(pos) != -1


## True if `pos` is a wall (collidable brick or stone) in the walls layer.
static func is_wall_at(layer: TileMapLayer, pos: Vector2i) -> bool:
	if not has_cell(layer, pos):
		return false
	var coord: Vector2i = layer.get_cell_atlas_coords(pos)
	return IsoTileCoordsScript.is_wall_tile(coord)


## True if `pos` is a closed door (player cannot pass).
static func is_door_closed_at(layer: TileMapLayer, pos: Vector2i) -> bool:
	if not has_cell(layer, pos):
		return false
	var coord: Vector2i = layer.get_cell_atlas_coords(pos)
	return IsoTileCoordsScript.is_door_closed(coord)


## True if `pos` is a decor object (chest, altar, etc.).
static func is_decor_at(layer: TileMapLayer, pos: Vector2i) -> bool:
	if not has_cell(layer, pos):
		return false
	var coord: Vector2i = layer.get_cell_atlas_coords(pos)
	# Decor lives in rows 0-2 of the decor atlas.
	return coord.y in [0, 1, 2]


## True if `pos` should block player movement (wall OR closed door).
## Walls layer holds the collidable cells; decor layer normally does not.
static func is_solid_at(walls_layer: TileMapLayer, pos: Vector2i) -> bool:
	return is_wall_at(walls_layer, pos) or is_door_closed_at(walls_layer, pos)


## Walkability test using only collision layers (no physics raycast).
## `tile_pos` is the tile coord the player would step into.
static func can_step_into(walls_layer: TileMapLayer, tile_pos: Vector2i) -> bool:
	return not is_solid_at(walls_layer, tile_pos)