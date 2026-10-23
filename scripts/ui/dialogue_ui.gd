extends CanvasLayer

@onready var speaker_label: Label = $DialoguePanel/SpeakerLabel
@onready var text_label: RichTextLabel = $DialoguePanel/TextLabel
@onready var continue_indicator: Label = $DialoguePanel/ContinueIndicator
@onready var background: Panel = $Background

const HINT_TEXT := "  (Press E to continue)"

var _current_npc_id: String = ""
var _current_data: DialogueData = null
var _current_line_index: int = 0
var _indicator_visible: bool = true

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_local_overrides()
	EventBus.dialogue_requested.connect(_on_dialogue_requested)

func _apply_local_overrides() -> void:
	if speaker_label:
		speaker_label.add_theme_font_size_override("font_size", UIMetrics.FONT_TITLE)
	if text_label:
		text_label.add_theme_font_size_override("normal_font_size", UIMetrics.FONT_BODY_LARGE)
		text_label.add_theme_font_size_override("bold_font_size", UIMetrics.FONT_BODY_LARGE + 2)

func _on_dialogue_requested(npc_id: String, data: DialogueData) -> void:
	if data == null or data.lines.is_empty():
		return
	_current_npc_id = npc_id
	_current_data = data
	_current_line_index = 0
	visible = true
	GameManager.change_state(GameManager.GameState.DIALOGUE)
	_show_current_line()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if continue_indicator != null and visible:
		_indicator_visible = fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0
		continue_indicator.visible = _indicator_visible

func _advance() -> void:
	_current_line_index += 1
	if _current_line_index >= _current_data.lines.size():
		_close()
	else:
		_show_current_line()

func _show_current_line() -> void:
	var line: DialogueLine = _current_data.lines[_current_line_index]
	speaker_label.text = line.speaker
	var show_hint := _current_line_index == 0 and not _is_final_line()
	text_label.text = line.text + (HINT_TEXT if show_hint else "")
	continue_indicator.visible = not show_hint

func _is_final_line() -> bool:
	return _current_line_index >= _current_data.lines.size() - 1

func _close() -> void:
	var last_line: DialogueLine = _current_data.get_last_line()
	var npc_id: String = _current_npc_id
	visible = false
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	EventBus.dialogue_ended.emit(npc_id)
	if last_line != null and not last_line.event_type.is_empty():
		DialogueManager.process_event(last_line.event_type, last_line.event_data)
	_current_data = null
	_current_npc_id = ""