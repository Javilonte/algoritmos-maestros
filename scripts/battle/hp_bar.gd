extends ProgressBar
class_name HPBar

## Barra de HP neón.
##
## ponytail: el relleno usaba la rampa roja de Diablo II (HP_RED_HI para
## un HP lleno). Un HP al 100% en rojo no dice nada — el color ES la
## informacion. Ahora la rampa es verde -> ambar -> rojo, y vive en
## CyberStyleBox con el resto de la paleta de combate.
##
## ponytail: `percent_text` NO se llama `show_percentage` porque
## ProgressBar ya tiene esa propiedad y GDScript rechaza el sombra.

## Which side this bar represents. Allowed values: "player", "enemy" and
## "xp". "xp" is the special case: it fills with cyan instead of the HP
## ramp. Any other value falls back to the HP ramp.
@export var side: String = "enemy"
## ponytail: la barra de XP del menuStatsPanel conserva su etiqueta de
## porcentaje; la de combate la apaga y muestra "cur/max" como texto aparte.
@export var percent_text: bool = true

func _ready() -> void:
	add_theme_stylebox_override("background", CyberStyleBox.track())
	add_theme_stylebox_override("fill", CyberStyleBox.fill(CyberStyleBox.hp_color(1.0)))
	show_percentage = percent_text
	value = max_value

func set_hp(current: int, max_hp: int) -> void:
	max_value = max_hp
	value = clamp(current, 0, max_hp)
	_update_color()

func _update_color() -> void:
	var fill_ratio := float(value) / float(max_value) if max_value > 0 else 0.0
	var color: Color = CyberStyleBox.CYAN if side == "xp" else CyberStyleBox.hp_color(fill_ratio)
	add_theme_stylebox_override("fill", CyberStyleBox.fill(color))
