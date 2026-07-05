## Helpers para aplicar `D2StyleBox` a nodos UI de manera uniforme.
## Reemplaza los `_apply_local_overrides` ad-hoc que tenía cada script.

class_name UIStyle


## Aplica `D2StyleBox.panel_bronze()` al Panel dado.
static func apply_d2_panel(panel: Panel) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())


## Aplica la familia completa de estilos de Button (normal/hover/pressed/disabled)
## y fija tamaño mínimo según `UIMetrics.BTN_*`.
## `size` puede ser SM, MD o LG.
static func apply_d2_button(button: Button, size: String = "MD") -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", D2StyleBox.button_normal())
	button.add_theme_stylebox_override("hover", D2StyleBox.button_hover())
	button.add_theme_stylebox_override("pressed", D2StyleBox.button_pressed())
	button.add_theme_stylebox_override("disabled", D2StyleBox.button_disabled())
	button.add_theme_stylebox_override("focus", D2StyleBox.button_normal())
	var h: int = UIMetrics.BTN_HEIGHT_MD
	var w: int = UIMetrics.BTN_WIDTH_MD
	match size:
		"SM":
			h = UIMetrics.BTN_HEIGHT_SM
			w = UIMetrics.BTN_WIDTH_SM
		"LG":
			h = UIMetrics.BTN_HEIGHT_LG
			w = UIMetrics.BTN_WIDTH_LG
	button.custom_minimum_size = Vector2(w, h)


## Aplica `D2StyleBox.code_inner()` en sus variantes normal/focus/read_only.
static func apply_d2_code_edit(code_edit: Control) -> void:
	if code_edit == null:
		return
	var inner := D2StyleBox.code_inner()
	var inner_focus := D2StyleBox.code_inner()
	code_edit.add_theme_stylebox_override("normal", inner)
	code_edit.add_theme_stylebox_override("focus", inner_focus)
	if code_edit.has_method("is_editing"):
		code_edit.add_theme_stylebox_override("read_only", inner)


## Aplica el color y tamaño de fuente de paleta a un Label o RichTextLabel.
static func apply_d2_label(label: Control, color_kind: int = 0, size_kind: int = 1) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", UIResolve.label_color(color_kind))
	label.add_theme_font_size_override("font_size", UIResolve.label_size(size_kind))
