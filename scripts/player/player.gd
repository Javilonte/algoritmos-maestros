extends CharacterBody2D

@export var speed: float = 300.0
@export var friction: float = 1500.0

var _input_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	_input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if not GameManager.is_player_input_allowed():
		_input_vector = Vector2.ZERO

	if _input_vector != Vector2.ZERO:
		velocity = _input_vector * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * _delta)

	move_and_slide()
