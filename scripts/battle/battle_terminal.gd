extends CanvasLayer
class_name BattleTerminal

signal back_pressed

@onready var code_editor: CodeEdit = $Panel/CodeEdit
@onready var console_output: RichTextLabel = $Panel/ConsoleScroll/ConsoleOutput
@onready var submit_button: Button = $Panel/SubmitButton
@onready var back_button: Button = $Panel/BackButton
@onready var panel: Panel = $Panel
@onready var title: Label = $Panel/TitleBar
@onready var console_caption: Label = $Panel/ConsoleLabel
@onready var separator_1: ColorRect = $Panel/Separator1
@onready var separator_2: ColorRect = $Panel/Separator2

var _challenge_id: String = "bubble_sort"
var _is_locked: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_cyber_style()
	EventBus.compiling_progress.connect(_on_compiling_progress)
	EventBus.compiling_finished.connect(_on_compiling_finished)


## ponytail: el tema global del juego es la paleta de Diablo II y NUNCA
## seteo `CodeEdit/colors/background_color`, asi que el editor heredaba el
## gris claro por defecto de Godot: el codigo se leia como texto oscuro
## sobre un rectangulo blanco, lo contrario de un editor neón. El fondo
## del CodeEdit lo pinta su color de tema, NO su stylebox — hay que
## cambiar los dos.
##
## ponytail: la terminal conserva el VERDE como identidad propia ("estoy
## en el modo codigo") pero ese verde sale de la paleta compartida, no de
## un color suelto.
func _apply_cyber_style() -> void:
	panel.add_theme_stylebox_override("panel", CyberStyleBox.panel(CyberStyleBox.GREEN, Color(0.01, 0.03, 0.025, 0.98)))

	code_editor.add_theme_color_override("background_color", CyberStyleBox.EDITOR_BG)
	code_editor.add_theme_color_override("font_color", CyberStyleBox.TEXT)
	code_editor.add_theme_color_override("font_uneditable_color", CyberStyleBox.TEXT_DIM)
	code_editor.add_theme_color_override("font_readonly_color", CyberStyleBox.TEXT_DIM)
	code_editor.add_theme_color_override("font_selected_color", Color(1, 1, 1))
	code_editor.add_theme_color_override("caret_color", CyberStyleBox.GREEN)
	code_editor.add_theme_color_override("selection_color", Color(0.30, 0.95, 0.50, 0.25))
	code_editor.add_theme_color_override("line_highlight_color", Color(0.30, 0.95, 0.50, 0.05))
	code_editor.add_theme_stylebox_override("normal", CyberStyleBox.editor())
	code_editor.add_theme_stylebox_override("focus", CyberStyleBox.editor())
	code_editor.add_theme_stylebox_override("read_only", CyberStyleBox.editor())

	title.add_theme_color_override("font_color", CyberStyleBox.GREEN)
	console_caption.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	separator_1.color = Color(CyberStyleBox.GREEN.r, CyberStyleBox.GREEN.g, CyberStyleBox.GREEN.b, 0.35)
	separator_2.color = Color(CyberStyleBox.GREEN.r, CyberStyleBox.GREEN.g, CyberStyleBox.GREEN.b, 0.35)

	submit_button.add_theme_stylebox_override("normal", CyberStyleBox.button(CyberStyleBox.GREEN))
	submit_button.add_theme_stylebox_override("hover", CyberStyleBox.button_hover(CyberStyleBox.GREEN))
	submit_button.add_theme_stylebox_override("pressed", CyberStyleBox.button_pressed(CyberStyleBox.GREEN))
	submit_button.add_theme_stylebox_override("focus", CyberStyleBox.button_hover(CyberStyleBox.GREEN))
	submit_button.add_theme_color_override("font_color", CyberStyleBox.GREEN)
	submit_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	submit_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	# "Back" no es una accion de ataque: es la salida. Neutra y apagada.
	back_button.add_theme_stylebox_override("normal", CyberStyleBox.button(CyberStyleBox.TEXT_DIM))
	back_button.add_theme_stylebox_override("hover", CyberStyleBox.button_hover(CyberStyleBox.TEXT_DIM))
	back_button.add_theme_stylebox_override("pressed", CyberStyleBox.button_pressed(CyberStyleBox.TEXT_DIM))
	back_button.add_theme_stylebox_override("focus", CyberStyleBox.button_hover(CyberStyleBox.TEXT_DIM))
	back_button.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	back_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	back_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))


func open_for(challenge_id: String) -> void:
	_challenge_id = challenge_id
	_reset_submit_lock()
	var challenge: ChallengeResource = ChallengeRegistry.get_by_id(challenge_id)
	code_editor.text = challenge.starter_code if challenge != null else ""
	console_output.text = "[color=%s]// Write code to attack![/color]\n" % CyberStyleBox.hex(CyberStyleBox.TEXT_DIM)
	visible = true
	code_editor.grab_focus()

func close() -> void:
	visible = false
	_reset_submit_lock()

func _reset_submit_lock() -> void:
	_is_locked = false
	submit_button.disabled = false

func _on_submit_pressed() -> void:
	if _is_locked:
		return
	_is_locked = true
	submit_button.disabled = true
	console_output.append_text("[color=%s]>> Compiling and running...[/color]\n" % CyberStyleBox.hex(CyberStyleBox.AMBER))
	CodeCompiler.compile_and_execute(_challenge_id, code_editor.text)

func _on_back_pressed() -> void:
	if _is_locked:
		return
	close()
	back_pressed.emit()

func _on_compiling_progress(stage: String, ratio: float) -> void:
	if not visible:
		return
	var bar := "["
	var total := 20
	var filled := int(round(ratio * total))
	for i in total:
		bar += "█" if i < filled else "░"
	bar += "]"
	console_output.append_text("[color=%s]>> %s %s %d%%[/color]\n" % [
		CyberStyleBox.hex(CyberStyleBox.GREEN), stage, bar, int(ratio * 100)])

func _on_compiling_finished(success: bool, message: String) -> void:
	_reset_submit_lock()
	if not visible:
		return
	var prefix: String = "[color=%s][OK][/color]" % CyberStyleBox.hex(CyberStyleBox.GREEN)
	if not success:
		prefix = "[color=%s][FAIL][/color]" % CyberStyleBox.hex(CyberStyleBox.RED)
		# AST-style structural failures get a yellow tint to invite retry.
		if (message.find("AST:") != -1 or message.find("Function") != -1 or message.find("Return type") != -1 or message.find("body too simple") != -1):
			prefix = "[color=%s][AST][/color]" % CyberStyleBox.hex(CyberStyleBox.AMBER)
	console_output.append_text("%s %s\n" % [prefix, message])
