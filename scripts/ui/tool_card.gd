extends PanelContainer
class_name ToolCard

## Una herramienta del arsenal: un fragmento de C++ que el jugador
## arrastra al editor (o clica) para insertarlo.
##
## ponytail: es un "modificador corporal" del codigo: el jugador no
## escribe el `for` ni el `if`, lo agarra de un panel y lo pega en su
## funcion. El juego lo hace GANANDO: cada enemigo del capitulo trae la
## herramienta de su concepto.

signal insert_requested(code: String)

var title_label: Label = null
var body_label: Label = null
var origin_label: Label = null

var tool_id: String = ""
var tool_name: String = ""
var tool_code: String = ""
var origin: String = ""
var _data: Dictionary = {}


func setup(id: String, data: Dictionary, origin_text: String) -> void:
	tool_id = id
	tool_name = String(data.get("name", id))
	tool_code = String(data.get("code", ""))
	origin = origin_text
	_data = data
	_apply()


func _ready() -> void:
	_build()
	_apply()


## El panel se arma por codigo: la tarjeta se crea dinamica y no tiene
## escena propia.
func _build() -> void:
	if has_node("Margin"):
		title_label = get_node("Margin/VBox/Title")
		body_label = get_node("Margin/VBox/Body")
		origin_label = get_node("Margin/VBox/Origin")
		return
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 2)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", CyberStyleBox.GREEN)
	body_label = Label.new()
	body_label.name = "Body"
	body_label.add_theme_font_size_override("font_size", 11)
	body_label.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	origin_label = Label.new()
	origin_label.name = "Origin"
	origin_label.add_theme_font_size_override("font_size", 10)
	origin_label.add_theme_color_override("font_color", CyberStyleBox.AMBER)
	vbox.add_child(title_label)
	vbox.add_child(body_label)
	vbox.add_child(origin_label)
	margin.add_child(vbox)
	add_child(margin)
	add_theme_stylebox_override("panel", CyberStyleBox.card(CyberStyleBox.GREEN))


func _apply() -> void:
	if title_label:
		title_label.text = tool_name
	if body_label:
		body_label.text = String(_data.get("desc", ""))
	if origin_label:
		origin_label.text = origin


## El arrastre de Godot: lo que se lleva el "cursor" mientras arrastras.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = tool_name
	preview.add_theme_color_override("font_color", CyberStyleBox.GREEN)
	preview.add_theme_font_size_override("font_size", 13)
	set_drag_preview(preview)
	return {"tool_code": tool_code, "tool_name": tool_name}


## Un clic tambien inserta: el arrastre es lo lindo, el clic es lo que
## funciona siempre (y en una pantalla tactil).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		insert_requested.emit(tool_code)
