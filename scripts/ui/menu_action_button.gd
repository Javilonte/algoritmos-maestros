extends Button
class_name MenuActionButton

## ponytail: themed main-menu action button. Variants:
##   - "primary"   (QuickStart): cyan, large
##   - "neutral"   (Continue/NewGame): steel border
##   - "subtle"    (Options): dimmer steel, smaller
##   - "danger"    (Exit): danger-red border
##
## ponytail: los botones usaban D2StyleBox (oro y bronce) mientras la
## pantalla de combate ya era neón: el menu y el combate parecian dos
## juegos. Ahora las cuatro variantes salen de CyberStyleBox.
##
## On hover/press the button scales via CyberpunkButton. The label
## supports an optional subtitle line rendered as a smaller secondary
## label below.

enum Variant { PRIMARY, NEUTRAL, SUBTLE, DANGER }

const VARIANT_NAMES: Dictionary = {
	"primary": Variant.PRIMARY,
	"neutral": Variant.NEUTRAL,
	"subtle": Variant.SUBTLE,
	"danger": Variant.DANGER,
}

@export var variant: String = "neutral"
## ponytail: el prefijo de icono quedo como opcion pero el menu no lo
## usa: los emoji (⚡ ▶ ✦) se renderizan con la fuente del sistema, con
## metricas propias y fuera de la paleta.
@export var icon_prefix: String = ""
@export var subtitle: String = ""

var _hover_wrapper: CyberpunkButton = null
var _primary_label: Label
var _subtitle_label: Label
var _vbox: VBoxContainer


func _ready() -> void:
	_apply_variant()
	_build_content()
	_hover_wrapper = CyberpunkButton.make_hoverable(self)
	# ponytail: ActionButton must be keyboard-navigable.
	focus_mode = Control.FOCUS_ALL


func _apply_variant() -> void:
	var v: int = _resolve_variant(variant)
	var accent: Color = _accent_for(v)
	var font_size: int = 18
	var font: Color = CyberStyleBox.TEXT
	match v:
		Variant.PRIMARY:
			font_size = 22
			font = CyberStyleBox.CYAN
		Variant.NEUTRAL:
			font_size = 17
			font = CyberStyleBox.TEXT
		Variant.SUBTLE:
			font_size = 15
			font = CyberStyleBox.TEXT_DIM
		Variant.DANGER:
			font_size = 15
			font = CyberStyleBox.TEXT_DIM

	add_theme_stylebox_override("normal", CyberStyleBox.button(accent))
	add_theme_stylebox_override("hover", CyberStyleBox.button_hover(accent))
	add_theme_stylebox_override("pressed", CyberStyleBox.button_pressed(accent))
	add_theme_stylebox_override("focus", CyberStyleBox.button_hover(accent))
	add_theme_stylebox_override("disabled", CyberStyleBox.button(CyberStyleBox.TEXT_DIM))
	add_theme_color_override("font_color", font)
	add_theme_color_override("font_hover_color", Color(1, 1, 1))
	add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	add_theme_color_override("font_disabled_color", CyberStyleBox.TEXT_DIM.darkened(0.3))
	add_theme_font_size_override("font_size", font_size)


## El acento de cada variante. ponytail: el magenta y el rojo no se usan
## aca a proposito — magenta significa ENEMIGO en la pantalla de combate
## y el rojo es el de perder.
func _accent_for(v: int) -> Color:
	match v:
		Variant.PRIMARY:
			return CyberStyleBox.CYAN
		Variant.NEUTRAL:
			return CyberStyleBox.STEEL
		Variant.SUBTLE:
			return CyberStyleBox.TEXT_DIM
		Variant.DANGER:
			return CyberStyleBox.RED
	return CyberStyleBox.STEEL


func _build_content() -> void:
	# ponytail: rebuild the button's content as a VBox so we can stack a
	# primary label + optional subtitle. The Button base class has a
	# `text` property, but that doesn't allow a secondary line; we drop
	# `text` and inject the labels manually.
	var base_text: String = text
	text = ""
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)
	# ponytail: un Button NO es un Container, asi que sus hijos NO se
	# acomodan: el VBox se quedaba en (0,0) con su tamano minimo y el
	# texto arrancaba pegado al borde del boton (la "I" de INICIO se
	# comia el marco). Anclarlo al rect completo lo arregla; los margenes
	# salen del propio stylebox, no de un numero repetido.
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb: StyleBox = get_theme_stylebox("normal")
	if sb != null:
		_vbox.offset_left = sb.get_margin(SIDE_LEFT)
		_vbox.offset_top = sb.get_margin(SIDE_TOP)
		_vbox.offset_right = -sb.get_margin(SIDE_RIGHT)
		_vbox.offset_bottom = -sb.get_margin(SIDE_BOTTOM)
	_primary_label = Label.new()
	_primary_label.text = (icon_prefix + " " + base_text).strip_edges()
	_primary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_primary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_vbox.add_child(_primary_label)
	# ponytail: only render the subtitle label if the caller provided
	# one. Empty subtitles would otherwise add an empty row of vertical
	# spacing in the VBox.
	if not subtitle.is_empty():
		_build_subtitle_label(subtitle)


## ponytail: change the visible label after the button was built (e.g. when
## save state changes and the Continue label toggles between
## "Continuar" / "Sin guardar").
func set_primary_label(new_text: String) -> void:
	if _primary_label:
		_primary_label.text = new_text


func set_subtitle_label(new_subtitle: String) -> void:
	if _subtitle_label == null and not new_subtitle.is_empty():
		_build_subtitle_label(new_subtitle)
		return
	if _subtitle_label:
		_subtitle_label.text = new_subtitle


func _build_subtitle_label(text_value: String) -> void:
	_subtitle_label = Label.new()
	_subtitle_label.text = text_value
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 11)
	_subtitle_label.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	_vbox.add_child(_subtitle_label)


func _resolve_variant(name: String) -> int:
	if VARIANT_NAMES.has(name):
		return VARIANT_NAMES[name]
	return Variant.NEUTRAL
