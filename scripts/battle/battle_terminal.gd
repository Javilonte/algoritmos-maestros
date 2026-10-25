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
@onready var contract_panel: Panel = $Panel/Contract
@onready var contract_text: RichTextLabel = $Panel/Contract/ContractText
@onready var checklist_timer: Timer = $ChecklistTimer

var _challenge_id: String = "bubble_sort"
var _challenge: ChallengeResource = null
var _is_locked: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_cyber_style()
	EventBus.compiling_progress.connect(_on_compiling_progress)
	EventBus.compiling_finished.connect(_on_compiling_finished)
	# ponytail: el checklist se recalcula mientras escribís, con un debounce
	# para no parsear el AST en cada tecla.
	code_editor.text_changed.connect(_on_code_text_changed)
	checklist_timer.timeout.connect(_on_checklist_timer_timeout)


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

	# ponytail: el bloque de contrato es donde el jugador descubre QUE
	# tiene que construir. Antes no existia: el editor abria con el
	# starter code y su unico comentario era "// tu codigo aqui".
	contract_panel.add_theme_stylebox_override("panel",
		CyberStyleBox.panel(CyberStyleBox.GREEN, Color(0.01, 0.045, 0.03, 0.92)))
	contract_text.add_theme_color_override("default_color", CyberStyleBox.TEXT)
	contract_text.add_theme_font_size_override("normal_font_size", 13)

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
	_challenge = ChallengeRegistry.get_by_id(challenge_id)
	_reset_submit_lock()
	var challenge: ChallengeResource = _challenge
	code_editor.text = challenge.starter_code if challenge != null else ""
	console_output.text = "[color=%s]// Write code to attack![/color]\n" % CyberStyleBox.hex(CyberStyleBox.TEXT_DIM)
	visible = true
	code_editor.grab_focus()
	_refresh_contract()


## El contrato del ejercicio: que hay que hacer, con que firma, que
## estructuras exige el analizador y como se ve un caso resuelto.
##
## ponytail: TODO esto ya estaba en los datos del challenge (prompt,
## function_signature, ast_required_features, test_cases) pero NADA lo
## mostraba. El jugador peleaba contra una tarea invisible.
func _refresh_contract() -> void:
	if _challenge == null:
		contract_text.text = ""
		return
	var green: String = CyberStyleBox.hex(CyberStyleBox.GREEN)
	var amber: String = CyberStyleBox.hex(CyberStyleBox.AMBER)
	var dim: String = CyberStyleBox.hex(CyberStyleBox.TEXT_DIM)
	var lines: Array[String] = []

	lines.append("[color=%s]OBJETIVO[/color]  %s" % [green, _escape_bbcode(_challenge.prompt)])
	lines.append("[color=%s]FIRMA[/color]     %s" % [green, _escape_bbcode(_challenge.function_signature)])

	# Los requisitos con el tick en vivo: el jugador ve lo que falta
	# ANTES de submitir, no despues del error.
	var status: Dictionary = AstValidator.feature_status(_last_ast())
	var req: Array[String] = []
	for feature in _challenge.ast_required_features:
		var ok: bool = bool(status.get(String(feature), false))
		var mark: String = "[color=%s]✓[/color]" % green if ok else "[color=%s]○[/color]" % amber
		req.append("%s %s" % [mark, AstValidator.feature_label(String(feature))])
	lines.append("[color=%s]REQUIERE[/color]  %s" % [green, "   ".join(req)])

	var examples: Array[String] = []
	for test in _challenge.test_cases:
		if examples.size() >= 2:
			break
		examples.append(_format_example(test))
	if examples.size() > 0:
		lines.append("[color=%s]EJEMPLOS[/color]  %s" % [green, "    ".join(examples)])
	else:
		lines.append("[color=%s]EJEMPLOS[/color]  [color=%s]el analizador solo pide que compiles[/color]" % [green, dim])

	contract_text.text = "\n".join(lines)


## Un caso resuelto, en sintaxis C++: climbStairs(3) → 3.
func _format_example(test: TestCase) -> String:
	var args: Array[String] = []
	for value in test.inputs:
		args.append(_format_value(value))
	return "%s(%s) → %s" % [
		_challenge.function_name_hint, ", ".join(args), _format_value(test.expected)]


func _format_value(value: Variant) -> String:
	if value is Array:
		var parts: Array[String] = []
		for item in value:
			parts.append(str(item))
		return "{%s}" % ", ".join(parts)
	return str(value)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


## El ultimo AST que se calculo del codigo del jugador.
func _last_ast() -> Dictionary:
	if _challenge == null:
		return {}
	return AstValidator.validate(code_editor.text, _challenge)


func _on_code_text_changed() -> void:
	checklist_timer.start()


func _on_checklist_timer_timeout() -> void:
	_refresh_contract()


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
	# ponytail: el checklist se refresca tambien en el submit. El timer de
	# debounce puede no haber disparado todavia y el contrato que ve el
	# jugador tiene que ser el del codigo que va a hacer falta.
	_refresh_contract()
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
