class_name SpriteInFrame

## Coloca un AnimatedSprite2D dentro de un area de arte (un Control) y lo
## escala contra el tamano REAL de esa area.
##
## ponytail: los contenedores de Godot SOLO ordenan hijos Control. Un
## AnimatedSprite2D es un Node2D, asi que un CenterContainer no lo mueve
## NUNCA y, con `centered = true`, se dibuja desde -size/2 alrededor del
## origen: medio personaje queda FUERA del marco. Medido en el retrato
## de combate: y = -8.4, por encima del tope de la pantalla; y en la
## ficha del menu: 46 px a la izquierda y 72 px por encima.
##
## ponytail: la escala sale del tamano real del area, no de una
## constante. Cuando el extractor regenera las hojas con otra celda,
## una escala absoluta se rompe en silencio.
##
## Este helper existe para que la aritmetica exista UNA vez. La segunda
## copia de "encajar un Node2D en un Control" es como el bug vuelve.

## Margen lateral del area de arte. Abajo no hay margen: el borde
## inferior del area es la linea de piso sobre la que se apoya el
## personaje.
const PADDING := 12.0


## Encaja el sprite en el area y lo apoya sobre la linea de piso.
## `fill` es la fraccion del area que el arte puede ocupar.
static func fit(sprite: AnimatedSprite2D, area: Control, fill: float = 0.92, padding: float = PADDING) -> void:
	if sprite == null or area == null:
		return
	var cell: Vector2 = frame_size(sprite)
	if cell.x <= 0.0 or cell.y <= 0.0:
		return
	var inner: Vector2 = Vector2(area.size.x - padding * 2.0, area.size.y - padding)
	if inner.x <= 0.0 or inner.y <= 0.0:
		return
	var scale_factor: float = minf(inner.x / cell.x, inner.y / cell.y) * fill
	sprite.scale = Vector2.ONE * scale_factor
	var drawn: Vector2 = cell * scale_factor
	# centrado en X, apoyado sobre la linea de piso en Y
	sprite.position = Vector2(area.size.x * 0.5, area.size.y - drawn.y * 0.5)


## Tamano de la celda del frame actual.
static func frame_size(sprite: AnimatedSprite2D) -> Vector2:
	if sprite == null or sprite.sprite_frames == null:
		return Vector2.ZERO
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return Vector2.ZERO
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if tex == null:
		return Vector2.ZERO
	return tex.region.size if tex is AtlasTexture else tex.get_size()


## Rect que el sprite ocupa de verdad en pantalla, en coordenadas globales.
## Lo usan los guards para comprobar que el arte NO se sale del marco.
static func drawn_rect(sprite: AnimatedSprite2D) -> Rect2:
	var cell: Vector2 = frame_size(sprite)
	if cell.x <= 0.0 or cell.y <= 0.0:
		return Rect2()
	var drawn: Vector2 = cell * sprite.scale
	return Rect2(sprite.global_position - drawn * 0.5, drawn)
