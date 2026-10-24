extends CharacterBody2D
class_name PlatformerPlayer

## Controller del plataformero. Reemplaza el movimiento sobre grilla isometrica
## por fisica de plataformas real: gravedad, salto, aceleracion, coyote time y
## jump buffer.
##
## ponytail: el origen del CharacterBody2D esta en los PIES, no en el centro.
## Asi el `position` de un nodo es el punto de apoyo sobre el tile y la
## colision y el sprite se desplazan hacia arriba con offsets. Es la
## convencion que hacen todos los plataformeros 2D y evita el clasico
## "medio pixel de despegarse del suelo".

const GRAVITY: float = 1800.0
const MAX_FALL_SPEED: float = 900.0
const RUN_SPEED: float = 220.0
const ACCELERATION: float = 1800.0
const FRICTION: float = 2400.0
const JUMP_VELOCITY: float = -620.0
## Fraccion de velocidad vertical conservada al soltar el salto: altura de
## salto variable (soltar temprano salta menos).
const JUMP_CUT: float = 0.45
## Margen para saltar justo despues de abandonar el borde.
const COYOTE_TIME: float = 0.12
## Margen para saltar un instante ANTES de tocar el suelo.
const JUMP_BUFFER: float = 0.12

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jump_cut_pending: bool = false
var _facing: int = 1

signal landed
signal jumped


func _ready() -> void:
	add_to_group("player")
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func _physics_process(delta: float) -> void:
	_horizontal(delta)
	_vertical(delta)
	move_and_slide()
	_update_animation()


## Movimiento horizontal con aceleracion y friccion.
func _horizontal(delta: float) -> void:
	var dir: float = Input.get_axis("move_left", "move_right")
	if not GameManager.is_player_input_allowed():
		dir = 0.0
	if absf(dir) > 0.01:
		velocity.x = move_toward(velocity.x, dir * RUN_SPEED, ACCELERATION * delta)
		_facing = 1 if dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)


## Gravedad, salto con coyote time y jump buffer.
func _vertical(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	if is_on_floor():
		if _coyote <= 0.0:
			landed.emit()
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_jump_cut_pending = true
		jumped.emit()

	# Altura de salto variable: al soltar el boton se corta la velocidad
	# vertical una sola vez.
	if _jump_cut_pending and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= JUMP_CUT
		_jump_cut_pending = false


func _update_animation() -> void:
	if sprite.sprite_frames == null:
		return
	var anim: String = "walk" if absf(velocity.x) > 10.0 else "idle"
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	sprite.flip_h = _facing < 0
