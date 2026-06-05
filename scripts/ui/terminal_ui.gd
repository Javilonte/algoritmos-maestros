extends CanvasLayer

@onready var code_editor: CodeEdit = $Panel/CodeEdit
@onready var console_output: RichTextLabel = $Panel/ConsoleOutput
@onready var http_request: HTTPRequest = $Panel/HTTPRequest

@export var backend_url: String = "https://httpbin.org/post"
@export var language: String = "cpp17"
@export var default_challenge_id: String = "main_exit_check"

var _is_terminal_open: bool = false
var _is_submitting: bool = false

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	hide_terminal()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_terminal"):
		if _is_tab_event(event) and code_editor != null and code_editor.has_focus():
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
	code_editor.grab_focus()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.change_state(GameManager.GameState.TERMINAL)
	EventBus.emit_terminal_toggled(true)

func hide_terminal() -> void:
	_is_terminal_open = false
	visible = false
	get_tree().paused = false
	if GameManager.is_state(GameManager.GameState.TERMINAL):
		GameManager.change_state(GameManager.GameState.OVERWORLD)
	EventBus.emit_terminal_toggled(false)

func submit_code() -> void:
	if _is_submitting:
		_log("[color=yellow]>> Submission already in flight, please wait...[/color]")
		return

	var code: String = code_editor.text
	var challenge_id: String = GameManager.current_challenge_id
	if challenge_id.is_empty():
		challenge_id = default_challenge_id

	_log("[color=yellow]>> Compiling and sending C++ code to backend (challenge: %s)...[/color]" % challenge_id)
	EventBus.code_submitted.emit(challenge_id, code)

	var payload := {
		"language": language,
		"code": code,
		"challenge_id": challenge_id,
	}
	var body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json"])

	var err := http_request.request(backend_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_submitting = false
		_log("[color=red]>> NETWORK ERROR: could not reach the backend.[/color]")
		EventBus.code_validated.emit(challenge_id, false, "network_error")
	else:
		_is_submitting = true

func validate_locally_only() -> void:
	if _is_submitting:
		_log("[color=yellow]>> Submission already in flight, please wait...[/color]")
		return

	var code: String = code_editor.text
	var challenge_id: String = GameManager.current_challenge_id
	if challenge_id.is_empty():
		challenge_id = default_challenge_id

	_log("[color=yellow]>> Validating locally (challenge: %s)...[/color]" % challenge_id)
	EventBus.code_submitted.emit(challenge_id, code)

	var result := CodeValidator.evaluate(challenge_id, code)
	if result.success:
		_log("[color=green]>> SUCCESS: %s[/color]" % result.message)
		EventBus.code_validated.emit(challenge_id, true, result.message)
		hide_terminal()
	else:
		_log("[color=red]>> FAILED: %s[/color]" % result.message)
		EventBus.code_validated.emit(challenge_id, false, result.message)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_submitting = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_log("[color=red]>> NETWORK ERROR: request failed (result=%d).[/color]" % result)
		EventBus.code_validated.emit(GameManager.current_challenge_id, false, "network_error")
		return

	if response_code < 200 or response_code >= 300:
		_log("[color=red]>> SERVER ERROR: backend returned HTTP %d.[/color]" % response_code)
		EventBus.code_validated.emit(GameManager.current_challenge_id, false, "server_error")
		return

	var text := body.get_string_from_utf8()
	var json: Variant = JSON.parse_string(text)
	if json == null:
		_log("[color=red]>> DATA ERROR: backend response is not valid JSON.[/color]")
		EventBus.code_validated.emit(GameManager.current_challenge_id, false, "invalid_json")
		return

	_log("[color=cyan]>> Response received from backend.[/color]")
	var challenge_id: String = GameManager.current_challenge_id
	if challenge_id.is_empty():
		challenge_id = default_challenge_id
	var validation := CodeValidator.evaluate(challenge_id, code_editor.text)
	if validation.success:
		_log("[color=green]>> SUCCESS: %s[/color]" % validation.message)
		EventBus.code_validated.emit(challenge_id, true, validation.message)
		hide_terminal()
	else:
		_log("[color=red]>> FAILED: %s[/color]" % validation.message)
		EventBus.code_validated.emit(challenge_id, false, validation.message)

func _log(bbcode: String) -> void:
	if console_output == null:
		return
	console_output.append_text(bbcode + "\n")

func _on_compile_button_pressed() -> void:
	submit_code()

func _on_validate_button_pressed() -> void:
	validate_locally_only()
