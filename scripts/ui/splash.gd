extends Control
class_name Splash

## ponytail: 2D-only splash screen. Cyberpunk neon aesthetic — dark
## background, scanline overlay, monospace typewriter that displays the
## boot sequence, then auto-dismisses to the main menu.
##
## Drops the original 80-frame PNG animation (was 8.4 MB on disk) for a
## text-based boot sequence. Same UX: short duration on first launch,
## press any key to skip, then advances to MAIN_MENU.
##
## Layout matches the boot/CRT theme used by main_menu.gd:
##   - corners [ ALGORITMOS MAESTROS OS ]  /  boot sequence 0x01
##   - mem / build info in opposite corners
##   - centered typewriter text
##   - scanline at top edge

const MAIN_MENU_PATH := "res://scenes/main_menu/main_menu.tscn"
const SHORT_DURATION: float = 1.6
const FADE_OUT_DURATION: float = 0.35
const TYPE_PER_CHAR: float = 0.04

signal splash_finished
signal splash_failed(reason: String)

@export var play_once: bool = true

@onready var _background: ColorRect = $Background
@onready var _scanline: ColorRect = $Scanline
@onready var _corner_tl: Label = $CornerTL
@onready var _corner_tr: Label = $CornerTR
@onready var _corner_bl: Label = $CornerBL
@onready var _corner_br: Label = $CornerBR
@onready var _logo_text: Label = $LogoText
@onready var _sub_text: Label = $SubText
@onready var _status_label: Label = $StatusLabel
@onready var _skip_hint: Label = $SkipHint
@onready var _type_timer: Timer = $TypeTimer

var _text_queue: Array[String] = []
var _current_text: String = ""
var _should_dismiss: bool = false
var _short_done: bool = false
var _safety_timer: SceneTreeTimer = null

const LINES: Array[String] = [
	"[ ALGORITMOS MAESTROS OS ]",
	"> initializing C++ trainer ...",
	"> loading challenges ....",
	"> linking skill tree .....",
	"> booting battle arena ...",
	"> system ready.",
]


func _ready() -> void:
	# ponytail: defense — never block the user forever if our setup fails.
	_safety_timer = get_tree().create_timer(8.0)
	_safety_timer.timeout.connect(_on_safety_timeout)

	_apply_style()
	_status_label.text = "boot sequence 0x01"
	_type_timer.timeout.connect(_on_type_tick)
	_corner_tl.text = "[ ALGORITMOS MAESTROS OS ]"
	_corner_tr.text = "mem: 0x7FFE  ok"
	_corner_bl.text = "build 0.1.0 / codename: BUBBLE_SORT"
	_corner_br.text = "v0.1.0 · dev build"
	_logo_text.text = ""
	_sub_text.text = ""
	_skip_hint.text = "[ PRESS ANY KEY TO SKIP ]"

	# Queue lines for typewriter.
	_text_queue = LINES.duplicate()
	_start_next_line()

	# Apply play_once policy.
	if play_once and _already_seen():
		_short_done = true
		_dismiss()


func _apply_style() -> void:
	_background.color = Color(0.02, 0.02, 0.04, 1)
	_scanline.color = Color(0.1, 0.6, 0.3, 0.25)
	_corner_tl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.35, 0.6))
	_corner_tr.add_theme_color_override("font_color", Color(0.3, 0.4, 0.35, 0.6))
	_corner_bl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.35, 0.6))
	_corner_br.add_theme_color_override("font_color", Color(0.3, 0.4, 0.35, 0.6))
	_logo_text.add_theme_color_override("font_color", Color(0.1, 0.9, 0.4, 1))
	_logo_text.add_theme_color_override("font_shadow_color", Color(0.02, 0.3, 0.1, 0.8))
	_logo_text.add_theme_constant_override("shadow_offset_x", 2)
	_logo_text.add_theme_constant_override("shadow_offset_y", 2)
	_logo_text.add_theme_font_size_override("font_size", 32)
	_sub_text.add_theme_color_override("font_color", Color(0.4, 0.6, 0.5, 0.85))
	_sub_text.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.1, 0.9, 0.4, 0.85))
	_status_label.add_theme_font_size_override("font_size", 14)
	_skip_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.55, 0.5))
	_skip_hint.add_theme_font_size_override("font_size", 12)


## ponytail: typewriter pops one character per tick. _start_next_line
## rotates between logo_text (header) and sub_text (status line) so the
## splash mimics a CRT boot sequence.
func _on_type_tick() -> void:
	if _text_queue.is_empty():
		_type_timer.stop()
		_finish_short()
		return
	var line: String = _text_queue[0]
	if _current_text.length() < line.length():
		_current_text = line.substr(0, _current_text.length() + 1)
		_apply_current_line_text()
		return
	# Line fully typed — move to next.
	_text_queue.remove_at(0)
	_current_text = ""
	if _text_queue.is_empty():
		_type_timer.stop()
		_finish_short()
		return
	# Pause briefly between lines.
	var pause: SceneTreeTimer = get_tree().create_timer(0.15)
	pause.timeout.connect(_start_next_line)


func _start_next_line() -> void:
	# ponytail: pick which label gets the next line based on queue
	# depth. We alternate but the first line always goes to the logo.
	if _logo_text.text == "":
		_logo_text.text = ""
	_current_text = ""
	_type_timer.start(TYPE_PER_CHAR)


func _apply_current_line_text() -> void:
	if _logo_text.text == "":
		_logo_text.text = _current_text
		_status_label.text = _current_text
		_sub_text.text = _current_text
		return
	# After the logo is set, subsequent lines go to sub_text and status_label.
	_sub_text.text = _current_text
	_status_label.text = _current_text


func _finish_short() -> void:
	if _short_done:
		return
	_short_done = true
	if play_once:
		_mark_seen()
	_dismiss()


func _dismiss() -> void:
	if _should_dismiss:
		return
	_should_dismiss = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	await fade.finished
	splash_finished.emit()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_safety_timeout() -> void:
	if not _short_done:
		splash_failed.emit("safety timeout")
		_dismiss()


func _unhandled_input(event: InputEvent) -> void:
	if not _short_done and event.is_pressed():
		_finish_short()


# ponytail: stored in SaveManager.settings["boot_seen"] so the splash
# plays only on the first launch. Subsequent launches skip straight to
# the main menu.
func _already_seen() -> bool:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("load_settings"):
		return false
	var settings: Dictionary = sm.load_settings()
	return bool(settings.get("boot_seen", false))


func _mark_seen() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("save_settings"):
		return
	var settings: Dictionary = sm.load_settings()
	settings["boot_seen"] = true
	sm.save_settings(settings)