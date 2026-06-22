extends Control

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var code_lines: Control = $CodeLines
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var cursor_label: Label = $CursorBlink

var _code_scroll_tween: Tween

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	continue_button.disabled = not SaveManager.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_spawn_floating_code()
	_apply_settings()

func _apply_settings() -> void:
	var settings := SaveManager.load_settings()
	if settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_continue_pressed() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		return
	GameManager.apply_save_data(data)
	_start_transition()

func _on_new_game_pressed() -> void:
	SaveManager.delete_save()
	GameManager.reset_to_new_game()
	_start_transition()

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/options_menu.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _start_transition() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/code_transition.tscn")

func _spawn_floating_code() -> void:
	if code_lines == null:
		return
	var lines: Array[Label] = []
	for child in code_lines.get_children():
		if child is Label:
			lines.append(child as Label)
	if lines.is_empty():
		return
	_code_scroll_tween = create_tween().set_loops()
	for line in lines:
		var target_y: float = line.position.y - 40.0
		_code_scroll_tween.tween_property(line, "position:y", target_y, 3.0 + randf() * 2.0).set_trans(Tween.TRANS_LINEAR)
		_code_scroll_tween.tween_callback(func() -> void:
			line.position.y = line.position.y + 400.0 + randf() * 200.0
			line.modulate.a = 0.04 + randf() * 0.06
		)

func _on_cursor_timer_timeout() -> void:
	if cursor_label != null:
		cursor_label.visible = not cursor_label.visible
