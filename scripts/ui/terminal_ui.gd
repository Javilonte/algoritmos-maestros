## Wrapper de `Terminal` específica del overworld. Composición:
## mantiene la instancia visual declarativa en la escena `TerminalUI.tscn`
## mientras concentra la lógica de red/validación local aquí.
##
## Ver `docs/UI_REFACTOR_PLAN.md` Fase 2.

extends CanvasLayer

const ValidationResultFormatter = preload("res://scripts/util/validation_result_formatter.gd")
const TerminalScene := preload("res://scenes/ui/terminal.tscn")

@export var backend_url: String = "https://httpbin.org/post"
@export var language: String = "cpp17"
@export var default_challenge_id: String = "main_exit_check"

var _is_terminal_open: bool = false
var _is_submitting: bool = false
var _terminal: Terminal
var _http: HTTPRequest


func _ready() -> void:
	_terminal = TerminalScene.instantiate()
	_terminal.context = "overworld"
	_terminal.title = "C++ Terminal — Validate Code"
	_terminal.subtitle = "[color=gray]// Submit code or run local validation[/color]"
	_terminal.submit_label = "Validate"
	_terminal.show_back = true
	_terminal.dimmer = true
	_terminal.status_bar = true
	_terminal.placeholder = "// Write your code here..."
	_terminal.hide()
	_terminal.submitted.connect(_on_terminal_submitted)
	_terminal.back_pressed.connect(hide_terminal)
	add_child(_terminal)

	_http = HTTPRequest.new()
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)

	hide_terminal()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_terminal"):
		if _is_tab_event(event) and _terminal != null and _terminal._code_edit != null and _terminal._code_edit.has_focus():
			return
		if GameManager.is_state(GameManager.GameState.TERMINAL) \
			or GameManager.is_player_input_allowed():
			toggle_terminal()
		get_viewport().set_input_as_handled()


func _is_tab_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB


func toggle_terminal() -> void:
	if _is_terminal_open:
		hide_terminal()
	else:
		show_terminal()


func show_terminal() -> void:
	_is_terminal_open = true
	visible = true
	_terminal.show()
	_terminal._code_edit.grab_focus()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.change_state(GameManager.GameState.TERMINAL)
	EventBus.emit_terminal_toggled(true)


func hide_terminal() -> void:
	_is_terminal_open = false
	visible = false
	if _terminal != null:
		_terminal.hide()
	get_tree().paused = false
	if GameManager.is_state(GameManager.GameState.TERMINAL):
		GameManager.change_state(GameManager.GameState.OVERWORLD)
	EventBus.emit_terminal_toggled(false)


func submit_code() -> void:
	if _is_submitting:
		_log(UIResolve.bbcode_status(UIResolve.Level.WARN, "Submission already in flight, please wait..."))
		return

	var code: String = _terminal.get_code()
	var challenge_id: String = GameManager.current_challenge_id
	if challenge_id.is_empty():
		challenge_id = default_challenge_id

	_log(UIResolve.bbcode_status(UIResolve.Level.INFO, "Compiling and sending C++ code to backend (challenge: %s)..." % challenge_id))
	EventBus.code_submitted.emit(challenge_id, code)

	var payload := {
		"language": language,
		"code": code,
		"challenge_id": challenge_id,
	}
	var body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json"])

	var err := _http.request(backend_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_submitting = false
		_log(UIResolve.bbcode_status(UIResolve.Level.ERR, "NETWORK ERROR: could not reach the backend."))
		EventBus.code_validated.emit(challenge_id, false, "network_error")
	else:
		_is_submitting = true


func validate_locally_only() -> void:
	if _is_submitting:
		_log(UIResolve.bbcode_status(UIResolve.Level.WARN, "Submission already in flight, please wait..."))
		return

	var code: String = _terminal.get_code()
	var challenge_id: String = GameManager.current_challenge_id
	if challenge_id.is_empty():
		challenge_id = default_challenge_id

	_log(UIResolve.bbcode_status(UIResolve.Level.INFO, "Validating locally (challenge: %s)..." % challenge_id))
	EventBus.code_submitted.emit(challenge_id, code)

	var result := CodeValidator.evaluate(challenge_id, code)
	_apply_validation_result(challenge_id, result)


func _on_terminal_submitted() -> void:
	submit_code()


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_submitting = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_log(UIResolve.bbcode_status(UIResolve.Level.ERR, "NETWORK ERROR: request failed (result=%d)." % result))
		EventBus.code_validated.emit(GameManager.current_challenge_id, false, "network_error")
		return

	if response_code < 200 or response_code >= 300:
		_log(UIResolve.bbcode_status(UIResolve.Level.ERR, "SERVER ERROR: backend returned HTTP %d." % response_code))
		EventBus.code_validated.emit(GameManager.current_challenge_id, false, "server_error")
		return

	var text := body.get_string_from_utf8()
	var json: Variant = JSON.parse_string(text)
	if json == null:
		_log(UIResolve.bbcode_status(UIResolve.Level.ERR, "DATA ERROR: backend response is not valid JSON."))
		EventBus.code_validated.emit(GameManager.current_challenge_id, false, "invalid_json")
		return

	_log(UIResolve.bbcode_status(UIResolve.Level.INFO, "Response received from backend."))
	var challenge_id: String = GameManager.current_challenge_id
	if challenge_id.is_empty():
		challenge_id = default_challenge_id
	var validation := CodeValidator.evaluate(challenge_id, _terminal.get_code())
	_apply_validation_result(challenge_id, validation)


func _apply_validation_result(challenge_id: String, result: Dictionary) -> void:
	var line: String = ValidationResultFormatter.format_line(result, "SUCCESS: ", "FAILED: ")
	var level := UIResolve.Level.OK if result.success else UIResolve.Level.ERR
	_log(UIResolve.bbcode_status(level, line.strip_edges()))
	EventBus.code_validated.emit(challenge_id, result.success, result.message)
	if result.success:
		hide_terminal()


func _log(bbcode: String) -> void:
	if _terminal == null:
		return
	_terminal.append_console(bbcode)
