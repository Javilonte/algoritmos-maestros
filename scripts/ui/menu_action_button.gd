extends Button
class_name MenuActionButton

## ponytail: themed main-menu action button. Variants:
##   - "primary"   (QuickStart): gold border, large
##   - "neutral"   (Continue/NewGame): bronze border
##   - "subtle"    (Options): thinner bronze, smaller
##   - "danger"    (Exit): danger-red border
##
## On hover/press the button scales via CyberpunkButton. The label
## supports an icon prefix (e.g. "⚡ Inicio Rápido") and an optional
## subtitle line rendered as a smaller secondary label below.

enum Variant { PRIMARY, NEUTRAL, SUBTLE, DANGER }

const VARIANT_NAMES: Dictionary = {
	"primary": Variant.PRIMARY,
	"neutral": Variant.NEUTRAL,
	"subtle": Variant.SUBTLE,
	"danger": Variant.DANGER,
}

@export var variant: String = "neutral"
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
	match v:
		Variant.PRIMARY:
			add_theme_stylebox_override("normal", D2StyleBox.button_neon_primary())
			add_theme_stylebox_override("hover", D2StyleBox.button_neon_primary())
			add_theme_stylebox_override("pressed", D2StyleBox.button_neon_primary())
			add_theme_stylebox_override("focus", D2StyleBox.button_neon_primary())
			add_theme_color_override("font_color", D2Palette.GOLD_TEXT_BRIGHT)
			add_theme_color_override("font_hover_color", Color(1, 0.95, 0.65, 1))
			add_theme_color_override("font_pressed_color", D2Palette.GOLD_TEXT)
			add_theme_font_size_override("font_size", 22)
		Variant.NEUTRAL:
			add_theme_stylebox_override("normal", D2StyleBox.button_neon_neutral())
			add_theme_stylebox_override("hover", D2StyleBox.button_neon_neutral())
			add_theme_stylebox_override("pressed", D2StyleBox.button_neon_neutral())
			add_theme_stylebox_override("focus", D2StyleBox.button_neon_neutral())
			add_theme_color_override("font_color", D2Palette.BONE_TEXT)
			add_theme_color_override("font_hover_color", D2Palette.NEON_CYAN)
			add_theme_color_override("font_pressed_color", D2Palette.GOLD_TEXT)
			add_theme_font_size_override("font_size", 16)
		Variant.SUBTLE:
			add_theme_stylebox_override("normal", D2StyleBox.button_neon_subtle())
			add_theme_stylebox_override("hover", D2StyleBox.button_neon_subtle())
			add_theme_stylebox_override("pressed", D2StyleBox.button_neon_subtle())
			add_theme_stylebox_override("focus", D2StyleBox.button_neon_subtle())
			add_theme_color_override("font_color", D2Palette.MUTED_TEXT)
			add_theme_color_override("font_hover_color", D2Palette.BONE_TEXT)
			add_theme_color_override("font_pressed_color", D2Palette.GOLD_TEXT)
			add_theme_font_size_override("font_size", 14)
		Variant.DANGER:
			add_theme_stylebox_override("normal", D2StyleBox.button_neon_danger())
			add_theme_stylebox_override("hover", D2StyleBox.button_neon_danger())
			add_theme_stylebox_override("pressed", D2StyleBox.button_neon_danger())
			add_theme_stylebox_override("focus", D2StyleBox.button_neon_danger())
			add_theme_color_override("font_color", D2Palette.MUTED_TEXT)
			add_theme_color_override("font_hover_color", D2Palette.DANGER_TEXT)
			add_theme_color_override("font_pressed_color", D2Palette.DANGER_TEXT)
			add_theme_font_size_override("font_size", 14)


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
	_primary_label = Label.new()
	_primary_label.text = (icon_prefix + " " + base_text).strip_edges()
	_primary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_primary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_vbox.add_child(_primary_label)
	# ponytail: only render the subtitle label if the caller provided
	# one. Empty subtitles would otherwise add an empty row of vertical
	# spacing in the VBox.
	if not subtitle.is_empty():
		_subtitle_label = Label.new()
		_subtitle_label.text = subtitle
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle_label.add_theme_font_size_override("font_size", 11)
		_subtitle_label.add_theme_color_override("font_color", D2Palette.MUTED_TEXT)
		_vbox.add_child(_subtitle_label)


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
	_subtitle_label.add_theme_color_override("font_color", D2Palette.MUTED_TEXT)
	_vbox.add_child(_subtitle_label)


func _resolve_variant(name: String) -> int:
	if VARIANT_NAMES.has(name):
		return VARIANT_NAMES[name]
	return Variant.NEUTRAL
