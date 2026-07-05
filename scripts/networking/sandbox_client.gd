extends Node
class_name SandboxClient

## Cliente HTTP para el sandbox Judge0.
## Maneja timeout, reintentos y fallback offline (AST local).

signal submission_completed(result: Dictionary)

const SANDBOX_URL: String = GameConstants.SANDBOX_BASE_URL
const LANGUAGE_ID_CPP: int = 54  # C++ (GCC 9.2.0)
const REQUEST_TIMEOUT_SEC: float = 5.0
const MAX_RETRIES: int = 1

@export var sandbox_online: bool = true

var _http: HTTPRequest
var _pending_uuid: String = ""
var _retries_left: int = 0
var _last_code: String = ""
var _last_context: Dictionary = {}

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

## Pings the Judge0 languages endpoint to verify connectivity.
func ping() -> bool:
	var headers := PackedStringArray([
		"Content-Type: application/json",
	])
	var err := _http.request(SANDBOX_URL + "/languages", headers, HTTPClient.METHOD_GET)
	if err != OK:
		sandbox_online = false
		return false
	var res: Array = await _http.request_completed
	sandbox_online = (int(res[1]) == 200)
	return sandbox_online

## Envia codigo al sandbox. Si esta offline, evalua localmente con AST simple.
func submit(code: String, time_left_at_submit: float, uuid: String) -> void:
	_pending_uuid = uuid
	_last_code = code
	_retries_left = MAX_RETRIES
	if not sandbox_online:
		_evaluate_local(code, time_left_at_submit, uuid)
		return
	_dispatch_http(code, time_left_at_submit, uuid)

func set_context(ctx: Dictionary) -> void:
	_last_context = ctx.duplicate()

func _dispatch_http(code: String, _time_left: float, _uuid: String) -> void:
	var b64 := Marshalls.raw_to_base64(code.to_utf8_buffer())
	var stdin_b64 := Marshalls.raw_to_base64(String(_last_context.get("stdin", "")).to_utf8_buffer())
	var expected_b64 := Marshalls.raw_to_base64(String(_last_context.get("expected_output", "")).to_utf8_buffer())
	var cpu_limit := float(_last_context.get("time_limit_sec", 2.0))
	var payload := {
		"source_code": b64,
		"language_id": LANGUAGE_ID_CPP,
		"base64_encoded": true,
		"stdin": stdin_b64,
		"expected_output": expected_b64,
		"cpu_time_limit": cpu_limit,
		"wall_time_limit": cpu_limit + 1.0,
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
	])
	var api_key := OS.get_environment("JUDGE0_RAPIDAPI_KEY")
	var api_host := OS.get_environment("JUDGE0_RAPIDAPI_HOST")
	if not api_key.is_empty():
		headers.append("X-RapidAPI-Key: " + api_key)
		headers.append("X-RapidAPI-Host: " + (api_host if not api_host.is_empty() else "judge0-ce.p.rapidapi.com"))
	var err := _http.request(
		SANDBOX_URL + "/submissions?base64_encoded=true&wait=true",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		_handle_network_error()

func _on_request_completed(result: int, code_resp: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code_resp != 200:
		_handle_network_error()
		return
	var text: String = body.get_string_from_utf8()
	var json: Dictionary = JSON.parse_string(text)
	if json == null or json.is_empty():
		_handle_network_error()
		return
	submission_completed.emit(_format_result(json))

func _handle_network_error() -> void:
	if _retries_left > 0:
		_retries_left -= 1
		await get_tree().create_timer(0.5).timeout
		_dispatch_http(_last_code, 0.0, _pending_uuid)
		return
	sandbox_online = false
	_evaluate_local(_last_code, 0.0, _pending_uuid)

func _evaluate_local(code: String, time_left: float, uuid: String) -> void:
	var local: LocalCppEvaluator = LocalCppEvaluator.new()
	var result: Dictionary = local.evaluate(code, time_left)
	result["uuid"] = uuid
	result["offline"] = true
	result["source_code"] = code
	var base_score := int(_last_context.get("base_score", 10))
	var compiled: bool = bool(result.get("compiled", false))
	# Offline: no podemos verificar la salida. Compilacion OK = base_score completa
	# para que el slice sea jugable sin Judge0 key. El multiplicador 0.5 ya viene
	# del DamageResolver cuando result["offline"] == true.
	result["matches_expected"] = compiled
	result["score"] = base_score if compiled else 0
	submission_completed.emit(result)

func _format_result(json: Dictionary) -> Dictionary:
	var status_id := int(json.get("status_id", 0))
	var compiled := status_id == 3  # Accepted
	var stdout_b64 := String(json.get("stdout", ""))
	var stderr_b64 := String(json.get("stderr", ""))
	var compile_b64 := String(json.get("compile_output", ""))
	var stdout := ""
	var stderr := ""
	var compile_msg := ""
	if not stdout_b64.is_empty():
		stdout = _b64_decode(stdout_b64)
	if not stderr_b64.is_empty():
		stderr = _b64_decode(stderr_b64)
	if not compile_b64.is_empty():
		compile_msg = _b64_decode(compile_b64)
	var expected := String(_last_context.get("expected_output", ""))
	var matches_expected := compiled and (expected.is_empty() or stdout.strip_edges() == expected.strip_edges())
	var base_score := int(_last_context.get("base_score", 10))
	return {
		"compiled": compiled,
		"stdout": stdout,
		"stderr": stderr,
		"compile_message": compile_msg,
		"time": float(json.get("time", "0.0")),
		"memory": int(json.get("memory", 0)),
		"status_id": status_id,
		"offline": false,
		"uuid": _pending_uuid,
		"matches_expected": matches_expected,
		"score": base_score if matches_expected else 0,
	}

func _b64_decode(s: String) -> String:
	var bytes := Marshalls.base64_to_raw(s)
	return bytes.get_string_from_utf8()
