extends ProgressBar
class_name HPBar

@export var side: String = "enemy"

func _ready() -> void:
	modulate = Color.GREEN
	value = max_value

func set_hp(current: int, max_hp: int) -> void:
	max_value = max_hp
	value = clamp(current, 0, max_hp)
	_update_color()

func _update_color() -> void:
	var ratio := float(value) / float(max_value) if max_value > 0 else 0.0
	if ratio > 0.5:
		modulate = Color.GREEN
	elif ratio > 0.25:
		modulate = Color.YELLOW
	else:
		modulate = Color.RED
