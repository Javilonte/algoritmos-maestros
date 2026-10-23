extends CharacterBody2D
class_name IsoPlayer

## Player con movimiento click-to-move en coordenadas isometricas.
## Sigue el cursor (mouse) o recibe destino via set_destination().
##
## El sprite se renderiza como un rombo isometrico procedural.

const SPEED := 180.0
const ARRIVAL_THRESHOLD := 4.0

@export var sprite_color: Color = D2Palette.SKILL_LIGHTNING

var _destination: Vector2 = Vector2.ZERO
var _has_destination: bool = false
var _origin: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

func _ready() -> void:
	add_to_group("player")
	z_index = 10
	_build_sprite()

func _build_sprite() -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Cuerpo del personaje: rombo azul con borde dorado.
	var cx := 24.0
	var cy := 28.0
	for y in range(48):
		for x in range(48):
			var dx: float = absf(x - cx)
			var dy: float = absf(y - cy)
			# Cuerpo principal: rombo 30x40.
			if dx / 16.0 + dy / 20.0 <= 1.0:
				var h: int = (x * 7 + y * 11) % 5
				var c: Color = D2Palette.XP_BLUE
				if h == 0:
					c = D2Palette.XP_BLUE_HI
				img.set_pixel(x, y, c)
			# Borde dorado.
			elif dx / 16.0 + dy / 20.0 <= 1.15:
				img.set_pixel(x, y, D2Palette.GOLD_TEXT)
	# Cabeza (circulo arriba).
	for y in range(20):
		for x in range(48):
			var dx: float = absf(x - 24)
			if dx * dx + (y - 8) * (y - 8) <= 64:
				img.set_pixel(x, y, D2Palette.BONE_TEXT)
	if sprite:
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.centered = true
	# Shadow: ellipse oscura debajo.
	var shadow_img := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	shadow_img.fill(Color(0, 0, 0, 0))
	for y in range(16):
		for x in range(48):
			var dx: float = absf(x - 24)
			var dy: float = absf(y - 8)
			if dx * dx * 0.6 + dy * dy <= 80:
				shadow_img.set_pixel(x, y, Color(0, 0, 0, 0.5))
	if shadow:
		var shadow_tex := ImageTexture.create_from_image(shadow_img)
		shadow.texture = shadow_tex
		shadow.position = Vector2(0, 24)
		shadow.centered = true

func setup(origin: Vector2, start_grid: Vector2i) -> void:
	_origin = origin
	_destination = IsoMath.cartesian_to_screen(start_grid.x, start_grid.y, origin)
	global_position = _destination
	_has_destination = false

func set_destination(grid_pos: Vector2i) -> void:
	_destination = IsoMath.cartesian_to_screen(grid_pos.x, grid_pos.y, _origin)
	_has_destination = true

func _physics_process(delta: float) -> void:
	if not _has_destination:
		return
	var diff: Vector2 = _destination - global_position
	if diff.length() <= ARRIVAL_THRESHOLD:
		_has_destination = false
		velocity = Vector2.ZERO
	else:
		velocity = diff.normalized() * SPEED
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_state(GameManager.GameState.OVERWORLD):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var grid_pos: Vector2i = IsoMath.screen_to_cartesian(event.position, _origin)
		set_destination(grid_pos)