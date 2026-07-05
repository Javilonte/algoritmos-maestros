extends CanvasLayer
class_name BattleTerminal

signal back_pressed

@onready var code_editor: CodeEdit = $Panel/CodeEdit
@onready var console_output: RichTextLabel = $Panel/ConsoleScroll/ConsoleOutput
@onready var submit_button: Button = $Panel/SubmitButton
@onready var back_button: Button = $Panel/BackButton

var _challenge_id: String = "bubble_sort"
var _is_locked: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.compiling_progress.connect(_on_compiling_progress)
	EventBus.compiling_finished.connect(_on_compiling_finished)

func open_for(challenge_id: String) -> void:
	_challenge_id = challenge_id
	_reset_submit_lock()
	var challenge: ChallengeResource = ChallengeRegistry.get_by_id(challenge_id)
	code_editor.text = challenge.starter_code if challenge != null else ""
	console_output.text = "[color=gray]// Write code to attack![/color]\n"
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
	console_output.append_text("[color=yellow]>> Compiling and running...[/color]\n")
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
	console_output.append_text("[color=cyan]>> %s %s %d%%[/color]\n" % [stage, bar, int(ratio * 100)])

func _on_compiling_finished(success: bool, message: String) -> void:
	_reset_submit_lock()
	if not visible:
		return
	var prefix := "[color=green][OK][/color]" if success else "[color=red][FAIL][/color]"
	# AST-style structural failures get a yellow tint to invite retry.
	if not success and (message.find("AST:") != -1 or message.find("Function") != -1 or message.find("Return type") != -1 or message.find("body too simple") != -1):
		prefix = "[color=yellow][AST][/color]"
	console_output.append_text("%s %s\n" % [prefix, message])
