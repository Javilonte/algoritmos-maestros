extends Camera2D

@export var target_path: NodePath
@export var smoothing: float = 5.0
@export var iso_offset: Vector2 = Vector2(0, -32)

var _target: Node2D

func _ready() -> void:
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node2D

func _process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + iso_offset
	global_position = global_position.lerp(desired, clamp(smoothing * delta, 0.0, 1.0))