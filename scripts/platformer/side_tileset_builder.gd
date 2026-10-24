class_name SideTilesetBuilder

## Construye un TileSet de vista LATERAL (32x32) con tiles generados
## proceduralmente. Sin assets externos: todo se pinta con Image.fill_rect.
##
## El juego pivoteo de isometrico a plataformero 2D. Ningun asset de terreno
## del repo sirve para vista lateral: tilemap_cyberpunk_floors.png son rombos
## de 256x128 y los iso_*_atlas son caras de cubo de 50x56. Una cara
## superior de rombo no se puede convertir en un tile lateral, asi que el
## terreno se genera. Sigue el patron ya probado de D2IsoTilesetBuilder.
##
## Tiles generados (atlas 4 columnas x 2 filas = 8 tiles, 128x64):
##   0: void (transparente, sin colision)
##   1: ground_top   (superficie iluminada)
##   2: ground_fill  (tierra)
##   3: ground_dark  (tierra profunda)
##   4: block_stone  (bloque de piedra)
##   5: block_alt    (bloque de piedra variante)
##   6: brick        (ladrillo)
##   7: crystal      (acento solido)
##
## Todos los tiles salvo el 0 tienen colision de cuadrado completo.
##
## Ceiling: un solo tile de 32x32 y sin variantes por altura. Si el nivel
## necesita plataformas finas de una sola linea, agregar un tile mas con
## poligono de colision reducido.

const TILE_W := 32
const TILE_H := 32
const ATLAS_COLS := 4
const ATLAS_ROWS := 2
const ATLAS_W := TILE_W * ATLAS_COLS  # 128
const ATLAS_H := TILE_H * ATLAS_ROWS  # 64

# IDs semanticos (coinciden con la posicion en el atlas).
const T_VOID := 0
const T_GROUND_TOP := 1
const T_GROUND_FILL := 2
const T_GROUND_DARK := 3
const T_BLOCK := 4
const T_BLOCK_ALT := 5
const T_BRICK := 6
const T_CRYSTAL := 7

## IDs de tile con colision.
const SOLID_TILES: Array[int] = [
	T_GROUND_TOP, T_GROUND_FILL, T_GROUND_DARK,
	T_BLOCK, T_BLOCK_ALT, T_BRICK, T_CRYSTAL,
]


## Construye el TileSet y devuelve [TileSet, ImageTexture].
static func build() -> Array:
	var img := Image.create(ATLAS_W, ATLAS_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Fila superior: terreno.
	_paint_ground_top(img, 0, 0)
	_paint_ground_fill(img, 1, 0, D2Palette.STONE_MID)
	_paint_ground_fill(img, 2, 0, D2Palette.STONE_DARK)
	_paint_block(img, 3, 0, D2Palette.STONE_LIGHT, D2Palette.STONE_HIGHLIGHT)
	# Fila inferior: bloques y acentos.
	_paint_block(img, 0, 1, D2Palette.STONE_MID, D2Palette.STONE_LIGHT)
	_paint_brick(img, 1, 1)
	_paint_crystal(img, 2, 1)
	_paint_block(img, 3, 1, D2Palette.BRONZE_DARK, D2Palette.BRONZE_MID)

	var texture := ImageTexture.create_from_image(img)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_W, TILE_H)

	# Capa de fisica 0: colision de cuadrado completo en los tiles solidos.
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	tile_set.add_source(atlas)
	for i in range(ATLAS_COLS * ATLAS_ROWS):
		var pos := Vector2i(i % ATLAS_COLS, i / ATLAS_COLS)
		atlas.create_tile(pos)
		if SOLID_TILES.has(i):
			_add_box_collision(atlas, pos)
	return [tile_set, texture]


## Poligono de colision de cuadrado completo dentro del tile.
static func _add_box_collision(atlas: TileSetAtlasSource, pos: Vector2i) -> void:
	var data: TileData = atlas.get_tile_data(pos, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(0, 0),
		Vector2(TILE_W, 0),
		Vector2(TILE_W, TILE_H),
		Vector2(0, TILE_H),
	]))


## Superficie de terreno: borde superior iluminado, cuerpo oscuro.
static func _paint_ground_top(img: Image, col: int, row: int) -> void:
	var ox := col * TILE_W
	var oy := row * TILE_H
	img.fill_rect(Rect2i(ox, oy, TILE_W, TILE_H), D2Palette.STONE_MID)
	# Franja de superficie.
	img.fill_rect(Rect2i(ox, oy, TILE_W, 4), D2Palette.STONE_HIGHLIGHT)
	img.fill_rect(Rect2i(ox, oy + 4, TILE_W, 2), D2Palette.BRONZE_DARK)
	# Granos.
	_dither(img, ox, oy + 8, D2Palette.STONE_DARK, 5)


## Relleno de tierra con textura granulada.
static func _paint_ground_fill(img: Image, col: int, row: int, base: Color) -> void:
	var ox := col * TILE_W
	var oy := row * TILE_H
	img.fill_rect(Rect2i(ox, oy, TILE_W, TILE_H), base)
	_dither(img, ox, oy + 6, base.darkened(0.35), 6)


## Bloque de piedra con bisel.
static func _paint_block(img: Image, col: int, row: int, base: Color, edge: Color) -> void:
	var ox := col * TILE_W
	var oy := row * TILE_H
	img.fill_rect(Rect2i(ox, oy, TILE_W, TILE_H), base)
	img.fill_rect(Rect2i(ox, oy, TILE_W, 2), edge)
	img.fill_rect(Rect2i(ox, oy, 2, TILE_H), edge.darkened(0.25))
	img.fill_rect(Rect2i(ox + TILE_W - 2, oy, 2, TILE_H), base.darkened(0.4))
	img.fill_rect(Rect2i(ox, oy + TILE_H - 2, TILE_W, 2), base.darkened(0.4))


## Ladrillo con juntas.
static func _paint_brick(img: Image, col: int, row: int) -> void:
	var ox := col * TILE_W
	var oy := row * TILE_H
	img.fill_rect(Rect2i(ox, oy, TILE_W, TILE_H), D2Palette.BRONZE_DARK)
	var brick := D2Palette.BRONZE_MID
	for by in range(4):
		var offset := 0 if by % 2 == 0 else 8
		for bx in range(2):
			var x := ox + offset + bx * 16
			if x + 16 > ox + TILE_W:
				continue
			var w := mini(16, ox + TILE_W - x)
			img.fill_rect(Rect2i(x, oy + by * 8, w, 7), brick)


## Cristal luminoso (acento solido).
static func _paint_crystal(img: Image, col: int, row: int) -> void:
	var ox := col * TILE_W
	var oy := row * TILE_H
	img.fill_rect(Rect2i(ox, oy, TILE_W, TILE_H), D2Palette.STONE_DARK)
	var glow := D2Palette.NEON_CYAN
	img.fill_rect(Rect2i(ox + 8, oy + 4, 16, 24), glow.darkened(0.35))
	img.fill_rect(Rect2i(ox + 12, oy + 8, 8, 16), glow)


## Salpica rectangulos pequenos para romper la planitud.
static func _dither(img: Image, ox: int, oy: int, color: Color, count: int) -> void:
	for i in range(count):
		var x := ox + (i * 7) % (TILE_W - 4)
		var y := oy + (i * 5) % (TILE_H - 4)
		img.fill_rect(Rect2i(x, y, 3, 2), color)
