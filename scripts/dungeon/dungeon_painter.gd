class_name DungeonPainter

## Pinta un grid 2D (resultado del BSP generator) en una TileMapLayer.
## Cada celda del grid se traduce a un tile del atlas isometrico.
##
## Como TileMapLayer es 2D axis-aligned (no soporta tiles isométricos nativos),
## usamos una segunda representacion: cada tile del grid se renderiza como
## un Sprite2D (rombo) en la posicion isometrica calculada via IsoMath.
##
## Esto es mas simple y flexible que forzar TileMapLayer a modo iso custom.

const FLOOR_VARIANTS := [1, 2, 3]  # T_FLOOR, T_FLOOR_ALT, T_FLOOR_DARK

static func paint(grid: Array, tile_set: TileSet, tile_atlas: TileSetAtlasSource, parent: Node2D, origin: Vector2 = Vector2.ZERO) -> Dictionary:
	var floor_layer: TileMapLayer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = tile_set
	floor_layer.z_index = 0
	parent.add_child(floor_layer)

	var wall_layer: TileMapLayer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = tile_set
	wall_layer.z_index = 1
	parent.add_child(wall_layer)

	var floor_sprites: Array = []
	var wall_sprites: Array = []
	var tile_size := Vector2i(D2IsoTilesetBuilder.TILE_W, D2IsoTilesetBuilder.TILE_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = grid[0][0] if grid.size() > 0 and grid[0].size() > 0 else 1234

	# Para cada celda del grid:
	# - Si es floor o floor_alt: pintar como TileMapLayer cell + crear sprite isometrico.
	# - Si es wall: crear sprite isometrico con el tile adecuado segun orientacion.
	var height: int = grid.size()
	var width: int = grid[0].size() if height > 0 else 0

	for y in range(height):
		for x in range(width):
			var t: int = grid[y][x]
			var screen_pos: Vector2 = IsoMath.cartesian_to_screen(x, y, origin)
			if t == D2IsoTilesetBuilder.T_VOID or t == D2IsoTilesetBuilder.T_WALL_N or t == D2IsoTilesetBuilder.T_WALL_E or t == D2IsoTilesetBuilder.T_WALL_S or t == D2IsoTilesetBuilder.T_WALL_W:
				# Muro: sprite isometrico segun orientacion.
				var atlas_pos := _wall_atlas_pos_for_tile(t)
				var sprite := _make_iso_sprite(tile_atlas, atlas_pos, screen_pos, t)
				parent.add_child(sprite)
				wall_sprites.append(sprite)
			else:
				# Suelo: tile del TileMapLayer (para collision simple).
				var variant: int = FLOOR_VARIANTS[rng.randi() % FLOOR_VARIANTS.size()]
				floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(variant % D2IsoTilesetBuilder.ATLAS_COLS, variant / D2IsoTilesetBuilder.ATLAS_COLS))
				# Ademas un sprite isometrico encima para el look D2 (con borde bronce).
				var sprite := _make_iso_sprite(tile_atlas, Vector2i(variant % D2IsoTilesetBuilder.ATLAS_COLS, variant / D2IsoTilesetBuilder.ATLAS_COLS), screen_pos, variant)
				parent.add_child(sprite)
				floor_sprites.append(sprite)

	return {
		"floor_layer": floor_layer,
		"wall_layer": wall_layer,
		"floor_sprites": floor_sprites,
		"wall_sprites": wall_sprites,
	}

static func _wall_atlas_pos_for_tile(t: int) -> Vector2i:
	# Atlas layout: row 0 = floors, row 1 = walls (N, E, S, W).
	match t:
		D2IsoTilesetBuilder.T_WALL_N: return Vector2i(0, 1)
		D2IsoTilesetBuilder.T_WALL_E: return Vector2i(1, 1)
		D2IsoTilesetBuilder.T_WALL_S: return Vector2i(2, 1)
		D2IsoTilesetBuilder.T_WALL_W: return Vector2i(3, 1)
		_: return Vector2i(0, 1)

static func _make_iso_sprite(atlas: TileSetAtlasSource, atlas_pos: Vector2i, screen_pos: Vector2, _tile_id: int) -> Sprite2D:
	var region: Rect2i = atlas.get_tile_texture_region(atlas_pos)
	var atlas_tex: Texture2D = atlas.texture
	# AtlasTexture: sub-textura que muestra solo el tile.
	var atlas_sub := AtlasTexture.new()
	atlas_sub.atlas = atlas_tex
	atlas_sub.region = Rect2(region.position, region.size)
	var sprite := Sprite2D.new()
	sprite.texture = atlas_sub
	sprite.position = screen_pos
	# Centrar: el sprite mide TILE_W x TILE_H pero se ancla arriba-izq por defecto.
	sprite.centered = false
	return sprite