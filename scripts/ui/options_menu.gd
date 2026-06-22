extends Control

@onready var fullscreen_check: CheckButton = $CenterContainer/VBoxContainer/FullscreenCheck
@onready var volume_slider: HSlider = $CenterContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_label: Label = $CenterContainer/VBoxContainer/VolumeRow/VolumeLabel
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

var _settings: Dictionary = {}

func _ready() -> void:
	_settings = SaveManager.load_settings()
	fullscreen_check.button_pressed = _settings.get("fullscreen", false)
	volume_slider.value = _settings.get("volume", 80)
	_update_volume_label(volume_slider.value)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(_on_back_pressed)

func _on_fullscreen_toggled(pressed: bool) -> void:
	_settings["fullscreen"] = pressed
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	SaveManager.save_settings(_settings)

func _on_volume_changed(value: float) -> void:
	_settings["volume"] = int(value)
	_update_volume_label(value)
	SaveManager.save_settings(_settings)

func _update_volume_label(value: float) -> void:
	volume_label.text = "%d%%" % int(value)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
