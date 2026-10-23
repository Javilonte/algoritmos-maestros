class_name D2IsoTilesetBuilder

## Construye un TileSet isométrico dimétrico (64x32) con tiles generados proceduralmente.
## Sin assets externos: todo se pinta con Image.fill_rect + gradientes lineales.
##
## Tiles generados:
##   0: void (transparente)
##   1: floor (suelo de piedra, gris medio con variación)
##   2: floor_alt (suelo alternativo, ligeramente más oscuro)
##   3: floor_dark (suelo con grietas, más oscuro)
##   4: wall_north / 5: wall_east / 6: wall_south / 7: wall_west (muros con borde bronce)
##
## El atlas es 64x32 por tile, 4 columnas x 2 filas (8 tiles).
## Tamano total: 256x64.

const TILE_W := 64
const TILE_H := 32
const ATLAS_COLS := 4
const ATLAS_ROWS := 2
const ATLAS_W := TILE_W * ATLAS_COLS  # 256
const ATLAS_H := TILE_H * ATLAS_ROWS  # 64

# IDs semanticos (coinciden con la posicion en el atlas).
const T_VOID := 0
const T_FLOOR := 1
const T_FLOOR_ALT := 2
const T_FLOOR_DARK := 3
const T_WALL_N := 4
const T_WALL_E := 5
const T_WALL_S := 6
const T_WALL_W := 7

## Construye el TileSet y devuelve una tupla [TileSet, Image].
static func build() -> Array:
	var img := Image.create(ATLAS_W, ATLAS_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint_floor(img, 0, 0, D2Palette.STONE_MID)
	_paint_floor(img, 1, 0, D2Palette.STONE_DARK)
	_paint_floor(img, 2, 0, D2Palette.STONE_HIGHLIGHT)
	_paint_floor(img, 3, 0, D2Palette.STONE_LIGHT)
	# Walls (fila inferior).
	_paint_wall(img, 0, 1, D2Palette.STONE_LIGHT, "north")
	_paint_wall(img, 1, 1, D2Palette.STONE_LIGHT, "east")
	_paint_wall(img, 2, 1, D2Palette.STONE_LIGHT, "south")
	_paint_wall(img, 3, 1, D2Palette.STONE_LIGHT, "west")

	var texture := ImageTexture.create_from_image(img)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_W, TILE_H)
	# Tipos: 0=int, 1=float, 2=string, 3=bool.
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "walkable")
	tile_set.set_custom_data_layer_type(0, 3)  # bool
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, "block_vision")
	tile_set.set_custom_data_layer_type(1, 3)  # bool
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(2, "category")
	tile_set.set_custom_data_layer_type(2, 2)  # string
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	# Registrar cada tile en primer lugar, luego asignar custom data.
	for i in range(ATLAS_COLS * ATLAS_ROWS):
		var pos := Vector2i(i % ATLAS_COLS, i / ATLAS_COLS)
		atlas.create_tile(pos)
	tile_set.add_source(atlas)
	return [tile_set, texture]

## Pinta un tile suelo procedural con borde y variacion.
static func _paint_floor(img: Image, col: int, row: int, base: Color) -> void:
	var ox := col * TILE_W
	var oy := row * TILE_H
	# Forma de rombo (dimetrico 64x32):
	#   top: (32, 0)
	#   right: (64, 16)
	#   bottom: (32, 32)
	#   left: (0, 16)
	var cx := ox + TILE_W / 2.0
	var cy := oy + TILE_H / 2.0
	# Rellenar rombo via scanlines.
	for y in range(TILE_H):
		for x in range(TILE_W):
			# Distancia al centro como porcentaje desde el rombo.
			var dx: float = absf(x - cx)
			var dy: float = absf(y - cy)
			# En un rombo 2:1, los puntos estan dentro si: dx/32 + dy/16 <= 1.
			if dx / (TILE_W / 2.0) + dy / (TILE_H / 2.0) <= 1.0:
				# Variacion sutil pseudo-aleatoria (determinista por posicion).
				var h = (x * 31 + y * 17 + col * 53) % 11
				var tint: float = (h - 5) / 50.0  # -0.10 .. +0.10
				var c := base.lerp(base.lightened(0.5) if tint > 0 else base.darkened(0.3), absf(tint))
				img.set_pixel(ox + x, oy + y, c)
	# Borde bronce (1px) en el perimetro del rombo.
	for y in range(TILE_H):
		for x in range(TILE_W):
			var dx: float = absf(x - cx)
			var dy: float = absf(y - cy)
			var inside: float = dx / (TILE_W / 2.0) + dy / (TILE_H / 2.0)
			var outside: float = (dx + 1) / (TILE_W / 2.0) + dy / (TILE_H / 2.0) if dx + 1 < TILE_W / 2.0 else 2.0
			if inside <= 1.0 and outside > 1.0:
				img.set_pixel(ox + x, oy + y, D2Palette.BRONZE_DARK)

## Pinta un tile de muro (cara de un cubo isometrico segun orientacion).
## Para un tile isometrico, las 4 caras visibles del cubo son north/east/south/west.
## Cada cara es un rombo parcial en una esquina del tile.
static func _paint_wall(img: Image, col: int, row: int, base: Color, side: String) -> void:
	var ox := col * TILE_W
	var oy := row * TILE_H
	# Las 4 caras forman un cubo visto desde arriba-izquierda (D2 / Diablo style).
	# top face (north): rombo superior completo
	# left face (west): rombo inferior-izquierda
	# right face (east): rombo inferior-derecha
	# bottom invisible
	var cx := ox + TILE_W / 2.0
	var cy := oy + TILE_H / 2.0

	# Definir el poligono de la cara segun orientacion.
	var pts: Array[Vector2] = []
	match side:
		"north":
			# Cara superior: poligono completo arriba.
			pts = [
				Vector2(ox + TILE_W / 2.0, oy + 0),
				Vector2(ox + TILE_W, oy + TILE_H / 2.0),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H),
				Vector2(ox + 0, oy + TILE_H / 2.0),
			]
		"east":
			# Lateral derecha: triangulo inferior-derecho + parte superior.
			pts = [
				Vector2(ox + TILE_W, oy + TILE_H / 2.0),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H * 0.5),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H * 0.25),
			]
		"south":
			# Cara frontal (south, mirando al jugador): trapezoide inferior.
			pts = [
				Vector2(ox + TILE_W / 2.0, oy + TILE_H),
				Vector2(ox + TILE_W, oy + TILE_H / 2.0),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H * 0.5),
				Vector2(ox + 0, oy + TILE_H / 2.0),
			]
		"west":
			# Lateral izquierda: triangulo inferior-izquierdo + parte superior.
			pts = [
				Vector2(ox + 0, oy + TILE_H / 2.0),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H * 0.5),
				Vector2(ox + TILE_W / 2.0, oy + TILE_H * 0.25),
			]

	# Rellenar poligono via bounding box.
	var min_x := int(ox + TILE_W)
	var max_x := int(ox)
	var min_y := int(oy + TILE_H)
	var max_y := int(oy)
	for p in pts:
		min_x = min(min_x, int(p.x))
		max_x = max(max_x, int(p.x))
		min_y = min(min_y, int(p.y))
		max_y = max(max_y, int(p.y))
	min_x = clampi(min_x, ox, ox + TILE_W - 1)
	max_x = clampi(max_x, ox, ox + TILE_W - 1)
	min_y = clampi(min_y, oy, oy + TILE_H - 1)
	max_y = clampi(max_y, oy, oy + TILE_H - 1)

	# Y mas oscuro segun la cara (mas profundo = mas oscuro).
	var wall_color := base
	match side:
		"north": wall_color = base.lightened(0.15)
		"east": wall_color = base
		"south": wall_color = base.darkened(0.25)
		"west": wall_color = base.darkened(0.4)

	for y in range(min_y - oy, max_y - oy + 1):
		for x in range(min_x - ox, max_x - ox + 1):
			if _point_in_poly(Vector2(ox + x + 0.5, oy + y + 0.5), pts):
				# Variacion sutil de "piedra".
				var h: int = (x * 13 + y * 23 + col * 7) % 7
				var c: Color = wall_color
				if h == 0:
					c = wall_color.darkened(0.1)
				elif h == 1:
					c = wall_color.lightened(0.05)
				img.set_pixel(ox + x, oy + y, c)
	# Borde bronce en el contorno.
	for y in range(min_y - oy, max_y - oy + 1):
		for x in range(min_x - ox, max_x - ox + 1):
			var px := ox + x + 0.5
			var py := oy + y + 0.5
			if _point_in_poly_xy(px, py, pts):
				var edge := false
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						if not _point_in_poly_xy(px + dx, py + dy, pts):
							edge = true
					if edge:
						img.set_pixel(ox + x, oy + y, D2Palette.BRONZE_DARK)

static func _point_in_poly(p: Vector2, poly: Array) -> bool:
	return _point_in_poly_xy(p.x, p.y, poly)

static func _point_in_poly_xy(px: float, py: float, poly: Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var inside := false
	var j: int = n - 1
	for i in range(n):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if ((pi.y > py) != (pj.y > py)):
			var denom: float = pj.y - pi.y
			var x_intersect: float = pi.x + (py - pi.y) * (pj.x - pi.x) / denom if denom != 0 else pi.x
			if px < x_intersect:
				inside = not inside
		j = i
	return inside