extends Control

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

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
	# ponytail: apply the persisted volume on entry too — without this the
	# player would hear the previous session's level even after the slider
	# is at a different position.
	_apply_volume_to_buses(volume_slider.value)
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
	_apply_volume_to_buses(value)
	SaveManager.save_settings(_settings)

## Convert linear 0..100 to AudioServer dB and apply to Music + SFX buses.
## ponytail: 0% maps to -40 dB (effectively muted) instead of 1.0 linear
## (-infinity) so the AudioStreamPlayer doesn't error on zero volume.
func _apply_volume_to_buses(linear_0_100: float) -> void:
	var clamped: float = clampf(linear_0_100 / 100.0, 0.0, 1.0)
	var db: float = linear_to_db(clamped if clamped > 0.01 else 0.01)
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, db)

func _update_volume_label(value: float) -> void:
	volume_label.text = "%d%%" % int(value)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
