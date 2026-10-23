class_name IsoMath

## Conversion entre coordenadas cartesianas (grid) e isometricas (pantalla).
## Tile dimetrico: 64x32 px (ratio 2:1), convencion "D2 style":
##   - x crece hacia abajo-derecha
##   - y crece hacia abajo-izquierda
##
## cartesian_to_screen(x, y) -> Vector2  (posicion del tile en pantalla)
## screen_to_cartesian(screen_x, screen_y) -> Vector2i
##
## El origen (0,0) del grid se mapea a la posicion en pixeles dada.

const TILE_W := 64
const TILE_H := 32

static func cartesian_to_screen(x: int, y: int, origin: Vector2 = Vector2.ZERO) -> Vector2:
	var sx: float = (x - y) * (TILE_W * 0.5)
	var sy: float = (x + y) * (TILE_H * 0.5)
	return origin + Vector2(sx, sy)

static func screen_to_cartesian(screen_pos: Vector2, origin: Vector2 = Vector2.ZERO) -> Vector2i:
	var p := screen_pos - origin
	var x: float = (p.x / (TILE_W * 0.5) + p.y / (TILE_H * 0.5)) * 0.5
	var y: float = (p.y / (TILE_H * 0.5) - p.x / (TILE_W * 0.5)) * 0.5
	return Vector2i(int(round(x)), int(round(y)))

## Centro del tile en pantalla (no esquina).
static func tile_center(x: int, y: int, origin: Vector2 = Vector2.ZERO) -> Vector2:
	return cartesian_to_screen(x, y, origin)