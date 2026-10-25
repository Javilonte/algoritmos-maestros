extends Enemy
class_name PlatformerEnemy

## Enemigo del platformer: patrulla de un punto a otro.
##
## ponytail: `Enemy` (scripts/overworld) es el disparador de la batalla y
## lo usa también `battle_retry_guard`, así que no se toca. La patrulla es
## una cosa del platformer y vive en esta subclase.
##
## ponytail: el sprite es un Sprite2D, no un AnimatedSprite2D. La marcha se
## avanza a mano sobre la textura porque cambiar el tipo de nodo rompería
## el `@onready var sprite: Sprite2D` que el Enemy compartido espera.

const WALK_FPS: float = 6.0

## Rango de patrulla en píxeles. El mundo los calcula del nivel.
@export var patrol_min_x: float = 0.0
@export var patrol_max_x: float = 0.0
@export var patrol_speed: float = 26.0

var _direction: int = 1
var _walk_time: float = 0.0
var _walk_frame: int = 0


func _ready() -> void:
	super._ready()
	if patrol_max_x <= patrol_min_x:
		patrol_max_x = patrol_min_x + 1.0


func _physics_process(delta: float) -> void:
	# `Enemy` no mueve nada: sólo dispara la batalla al contacto. El
	# movimiento es de acá.
	# ponytail: un enemigo bloqueado esta dormido: no patrulla. Si
	# patrullara, pareceria vivo y el jugador pensaria que si se puede
	# pelear con el.
	if not visible or locked:
		return
	global_position.x += _direction * patrol_speed * delta
	if global_position.x <= patrol_min_x:
		global_position.x = patrol_min_x
		_direction = 1
	elif global_position.x >= patrol_max_x:
		global_position.x = patrol_max_x
		_direction = -1
	if sprite != null:
		sprite.flip_h = _direction < 0
	_advance_walk(delta)


## Avanza la animación de marcha cuadro a cuadro sobre la textura.
func _advance_walk(delta: float) -> void:
	if sprite == null or sprite_frames == null or not sprite_frames.has_animation("walk"):
		return
	var frames: int = sprite_frames.get_frame_count("walk")
	if frames <= 1:
		return
	_walk_time += delta
	var step: float = 1.0 / WALK_FPS
	while _walk_time >= step:
		_walk_time -= step
		_walk_frame = (_walk_frame + 1) % frames
	sprite.texture = sprite_frames.get_frame_texture("walk", _walk_frame)
