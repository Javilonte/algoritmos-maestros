extends ProgressBar
class_name HPBar

## Barra de HP estilo Diablo II.
## Cambia el color del `fill` StyleBox según el porcentaje:
##   > 50%: HP_RED_HI (rojo brillante)
##   > 25%: HP_RED (rojo sangre)
##   < 25%: HP_RED_LOW (rojo coagulado)

@export var side: String = "enemy"

func _ready() -> void:
	add_theme_stylebox_override("background", D2StyleBox.bar_bg())
	add_theme_stylebox_override("fill", D2StyleBox.bar_fill(D2Palette.HP_RED_HI))
	value = max_value

func set_hp(current: int, max_hp: int) -> void:
	max_value = max_hp
	value = clamp(current, 0, max_hp)
	_update_color()

func _update_color() -> void:
	var fill_ratio := float(value) / float(max_value) if max_value > 0 else 0.0
	var color: Color
	if fill_ratio > 0.5:
		color = D2Palette.HP_RED_HI
	elif fill_ratio > 0.25:
		color = D2Palette.HP_RED
	else:
		color = D2Palette.HP_RED_LOW
	add_theme_stylebox_override("fill", D2StyleBox.bar_fill(color))