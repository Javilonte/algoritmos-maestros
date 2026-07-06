extends CanvasLayer
class_name BattleTerminalBridge

## Bridge UI <-> GDExtension (CombatAlgorithmEvaluator).
##
## Flow:
##   1. Player types code into CodeEdit.
##   2. Player presses "Execute" or Shift+Enter.
##   3. We forward the code + challenge_id to CombatAlgorithmEvaluator (C++).
##   4. C++ validates AST via TreeSitterParser + simulates complexity + emits
##      `evaluation_complete(code_id, damage, complexity, success, error)`.
##   5. This script converts that into `damage_calculated(DamageRoll)` for the
##      Battle arena + updates the StatusLabel visually.

signal damage_calculated(roll: Dictionary)   # forwarded to Battle / HUD
signal evaluation_complete(result: Dictionary)  # raw C++ output
signal compile_error(line: int, message: String)

@export var challenge_id: String = "main_exit_check"
@export var damage_tier: String = "B"        # base tier; C++ returns exact tier

@onready var code_editor: CodeEdit = $Panel/CodeEditor
@onready var status_label: Label = $Panel/StatusLabel
@onready var run_button: Button = $Panel/ButtonRow/RunButton
@onready var clear_button: Button = $Panel/ButtonRow/ClearButton
@onready var back_button: Button = $Panel/ButtonRow/BackButton
@onready var title_label: Label = $Panel/TitleBar
@onready var challenge_label: RichTextLabel = $Panel/ChallengeLabel

var _evaluator: Object = null     # CombatAlgorithmEvaluator instance (lazy)
var _evaluation_id: int = 0       # monotonic, to discard stale responses


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	title_label.text = "▶ Algoritmos Terminal — %s" % challenge_id
	challenge_label.bbcode_enabled = true
	challenge_label.text = "[color=#88cc99]Challenge:[/color] [b]%s[/b]\n[color=#88cc99]Escribe el algoritmo y presiona ▶ Execute (Shift+Enter)[/color]" % challenge_id
	run_button.pressed.connect(_on_run_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	back_button.pressed.connect(close)
	code_editor.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") and event.shift_pressed:
		_on_run_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_for(p_challenge_id: String, starter_code: String = "") -> void:
	challenge_id = p_challenge_id
	title_label.text = "▶ Algoritmos Terminal — %s" % challenge_id
	code_editor.text = starter_code
	status_label.text = ""
	status_label.modulate = Color(1, 1, 1)
	visible = true
	code_editor.grab_focus()


func close() -> void:
	visible = false
	_evaluation_id += 1  # invalidate pending responses


func _on_clear_pressed() -> void:
	code_editor.clear()
	status_label.text = ""
	code_editor.grab_focus()


func _on_run_pressed() -> void:
	var code: String = code_editor.text
	if code.strip_edges().is_empty():
		status_label.text = "[color=#ff6666]// empty submission[/color]"
		status_label.modulate = Color(1, 0.4, 0.4)
		return

	_evaluator = _ensure_evaluator()
	if _evaluator == null:
		status_label.text = "[color=#ff6666]CombatAlgorithmEvaluator not available (extension not loaded).[/color]"
		return

	_evaluation_id += 1
	var my_id: int = _evaluation_id
	status_label.text = "[color=#88cc99]// compiling…[/color]"
	status_label.modulate = Color(0.6, 0.9, 0.6)

	# C++ signals are sync via binding; we still guard with my_id in case we
	# add async later.
	var result: Dictionary = _evaluator.evaluate(code, challenge_id)
	if my_id != _evaluation_id:
		return  # a newer evaluation supersedes this one

	_handle_evaluation_result(result)


func _ensure_evaluator() -> Object:
	## Lazy-load the GDExtension class. If the extension isn't built yet,
	## returns null and the UI shows a friendly error.
	if _evaluator != null and is_instance_valid(_evaluator):
		return _evaluator
	if not ClassDB.class_exists("CombatAlgorithmEvaluator"):
		push_warning("CombatAlgorithmEvaluator class not registered. Build the GDExtension.")
		return null
	var script_cls := load("res://gdextension/addons/algorithm-validator/bin/CombatAlgorithmEvaluator.gd") if false else null
	# Native class instantiation via ClassDB:
	var obj: Object = ClassDB.instantiate("CombatAlgorithmEvaluator")
	if obj == null:
		return null
	_evaluator = obj
	return _evaluator


func _handle_evaluation_result(result: Dictionary) -> void:
	evaluation_complete.emit(result)
	if not result.get("success", false):
		var err_msg: String = String(result.get("error_message", "unknown error"))
		var line: int = int(result.get("error_line", -1))
		status_label.text = "[color=#ff6666]// compile error (line %d): %s[/color]" % [line, err_msg]
		status_label.modulate = Color(1, 0.5, 0.5)
		compile_error.emit(line, err_msg)
		return

	var damage: int = int(result.get("damage", 0))
	var complexity: String = String(result.get("complexity", "O(?)"))
	var tier: String = String(result.get("tier", "X"))
	var ms: int = int(result.get("evaluation_ms", 0))
	status_label.text = "[color=#88ff88]// compiled OK — %s — %d dmg — TIER %s (%d ms)[/color]" % [complexity, damage, tier, ms]
	status_label.modulate = Color(0.5, 1.0, 0.6)

	# Forward as DamageRoll-shaped dictionary for the Battle arena.
	var roll: Dictionary = {
		"amount": damage,
		"tier": tier,
		"complexity": complexity,
		"evaluation_ms": ms,
		"challenge_id": challenge_id,
		"is_crit": tier == "S",
	}
	damage_calculated.emit(roll)