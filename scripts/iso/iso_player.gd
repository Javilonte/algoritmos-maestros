extends CharacterBody2D

const IsoCoordsScript = preload("res://scripts/iso/iso_coords.gd")

@export var speed: float = 200.0
@export var friction: float = 1500.0

var _input_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	z_index = 0

func _physics_process(_delta: float) -> void:
	_input_vector = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if not GameManager.is_player_input_allowed():
		_input_vector = Vector2.ZERO

	if _input_vector.length() > 0.001:
		var screen_velocity := IsoCoordsScript.iso_input_to_velocity(_input_vector)
		velocity = screen_velocity * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * _delta)

	move_and_slide()
	_update_z_sort()

func _update_z_sort() -> void:
	# Higher screen-y = deeper in the map = on top of tiles with lower screen-y.
	z_index = int(global_position.y)
	z_as_relative = false