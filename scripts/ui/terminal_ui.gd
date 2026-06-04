extends CanvasLayer

@onready var code_editor: CodeEdit = $Panel/CodeEdit
@onready var console_output: RichTextLabel = $Panel/ConsoleOutput
@onready var http_request: HTTPRequest = $Panel/HTTPRequest

@export var backend_url: String = "https://httpbin.org/post"
@export var language: String = "cpp17"
@export var default_challenge_id: String = "main_exit_check"

var _is_terminal_open: bool = false
var _active_request_id: int = -1
var _is_submitting: bool = false

static var REGEX_MAIN_EXIT: RegEx = RegEx.create_from_string(
	"(?xi) ^[\\s\\S]*? int\\s+main\\s*\\([^)]*\\)\\s*\\{[\\s\\S]*?return\\s+0\\s*;?[\\s\\S]*?\\} [\\s\\S]*? $"
)

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	hide_terminal()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_terminal"):
		if GameManager.is_state(GameManager.GameState.TERMINAL) \
			or GameManager.is_player_input_allowed():
			toggle_terminal()
		get_viewport().set_input_as_handled()

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
	_active_request_id = http_request.request(backend_url, headers, HTTPClient.METHOD_POST, body)
	if _active_request_id != OK:
		_is_submitting = false
		_log("[color=red]>> NETWORK ERROR: could not reach the backend.[/color]")
		EventBus.code_validated.emit(challenge_id, false, "network_error")
	else:
		_is_submitting = true

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
	_validate_locally(text)

func _validate_locally(raw_response: String) -> void:
	var challenge_id: String = GameManager.current_challenge_id
	if challenge_id.is_empty():
		challenge_id = default_challenge_id

	var result := _evaluate_challenge(challenge_id, code_editor.text, raw_response)
	if result.success:
		_log("[color=green]>> SUCCESS: %s[/color]" % result.message)
		EventBus.code_validated.emit(challenge_id, true, result.message)
		hide_terminal()
	else:
		_log("[color=red]>> FAILED: %s[/color]" % result.message)
		EventBus.code_validated.emit(challenge_id, false, result.message)

func _evaluate_challenge(challenge_id: String, code: String, _raw_response: String) -> Dictionary:
	match challenge_id:
		"main_exit_check":
			return _evaluate_main_exit_check(code)
		_:
			return {"success": false, "message": "Unknown challenge '%s'." % challenge_id}

func _evaluate_main_exit_check(code: String) -> Dictionary:
	if code.strip_edges().is_empty():
		return {"success": false, "message": "Code is empty."}

	var match_result := REGEX_MAIN_EXIT.search(code)
	if match_result == null:
		return {"success": false, "message": "Expected 'int main() { return 0; }'."}

	return {"success": true, "message": "Minimum C++ algorithm detected — damage dealt to monster."}

func _log(bbcode: String) -> void:
	if console_output == null:
		return
	console_output.append_text(bbcode + "\n")

func _on_compile_button_pressed() -> void:
	submit_code()
