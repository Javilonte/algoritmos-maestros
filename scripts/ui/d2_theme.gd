class_name D2Theme

## Builder del Theme global estilo Diablo II.
## Construye un Theme con StyleBoxes y colores por defecto que se aplica
## a `gui/theme/custom` en project.godot.

const FONT_SIZE_SMALL := 13
const FONT_SIZE_NORMAL := 15
const FONT_SIZE_LARGE := 18
const FONT_SIZE_TITLE := 24
const FONT_SIZE_HERO := 52

static func build() -> Theme:
	var theme := Theme.new()

	# Fuentes (default del sistema; el engine provee una por defecto).
	# Solo ajustamos tamaños.

	# Colores por defecto de texto.
	theme.set_color("font_color", "Label", D2Palette.BONE_TEXT)
	theme.set_color("font_color", "RichTextLabel", D2Palette.BONE_TEXT)
	theme.set_color("default_color", "RichTextLabel", D2Palette.BONE_TEXT)
	theme.set_color("font_color", "Button", D2Palette.BONE_TEXT)
	theme.set_color("font_hover_color", "Button", D2Palette.GOLD_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "Button", D2Palette.GOLD_TEXT)
	theme.set_color("font_disabled_color", "Button", D2Palette.MUTED_TEXT)
	theme.set_color("font_color", "LineEdit", D2Palette.BONE_TEXT)
	theme.set_color("font_color", "TextEdit", D2Palette.BONE_TEXT)
	theme.set_color("font_color", "CodeEdit", D2Palette.BONE_TEXT)
	theme.set_color("caret_color", "CodeEdit", D2Palette.GOLD_TEXT)
	theme.set_color("font_color", "ProgressBar", D2Palette.BONE_TEXT)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))

	# Tamaños por defecto.
	theme.set_font_size("font_size", "Label", FONT_SIZE_NORMAL)
	theme.set_font_size("font_size", "Button", FONT_SIZE_NORMAL)
	theme.set_font_size("font_size", "RichTextLabel", FONT_SIZE_NORMAL)
	theme.set_font_size("font_size", "LineEdit", FONT_SIZE_NORMAL)
	theme.set_font_size("font_size", "TextEdit", FONT_SIZE_NORMAL)
	theme.set_font_size("font_size", "CodeEdit", 14)
	theme.set_font_size("font_size", "ProgressBar", FONT_SIZE_SMALL)

	# StyleBoxes por defecto.
	theme.set_stylebox("panel", "Panel", D2StyleBox.panel_bronze())
	theme.set_stylebox("normal", "Button", D2StyleBox.button_normal())
	theme.set_stylebox("hover", "Button", D2StyleBox.button_hover())
	theme.set_stylebox("pressed", "Button", D2StyleBox.button_pressed())
	theme.set_stylebox("disabled", "Button", D2StyleBox.button_disabled())
	theme.set_stylebox("normal", "LineEdit", D2StyleBox.code_inner())
	theme.set_stylebox("focus", "LineEdit", D2StyleBox.code_inner())
	theme.set_stylebox("normal", "TextEdit", D2StyleBox.code_inner())
	theme.set_stylebox("focus", "TextEdit", D2StyleBox.code_inner())
	theme.set_stylebox("normal", "CodeEdit", D2StyleBox.code_inner())
	theme.set_stylebox("focus", "CodeEdit", D2StyleBox.code_inner())
	theme.set_stylebox("read_only", "CodeEdit", D2StyleBox.code_inner())
	theme.set_stylebox("background", "ProgressBar", D2StyleBox.bar_bg())

	return theme

static func save_to(path: String) -> void:
	var theme := build()
	var err := ResourceSaver.save(theme, path)
	if err != OK:
		push_error("D2Theme: failed to save theme to %s (err=%d)" % [path, err])