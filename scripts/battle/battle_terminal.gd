extends CanvasLayer
class_name BattleTerminal

const ValidationResultFormatter = preload("res://scripts/util/validation_result_formatter.gd")

signal submitted(success: bool)
signal back_pressed

@onready var code_editor: CodeEdit = $Panel/CodeEdit
@onready var console_output: RichTextLabel = $Panel/ConsoleOutput
@onready var submit_button: Button = $Panel/SubmitButton
@onready var back_button: Button = $Panel/BackButton

var _challenge_id: String = "main_exit_check"
var _is_locked: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	submit_button.pressed.connect(_on_submit_pressed)
	back_button.pressed.connect(_on_back_pressed)

func open_for(challenge_id: String) -> void:
	_challenge_id = challenge_id
	_is_locked = false
	code_editor.text = ""
	console_output.text = "[color=gray]// Write code to attack![/color]\n"
	visible = true
	code_editor.grab_focus()

func close() -> void:
	visible = false

func _on_submit_pressed() -> void:
	if _is_locked:
		return
	_is_locked = true
	var result := CodeValidator.evaluate(_challenge_id, code_editor.text)
	console_output.append_text(ValidationResultFormatter.format_line(result) + "\n")
	submitted.emit(result.success)

func _on_back_pressed() -> void:
	close()
	back_pressed.emit()
