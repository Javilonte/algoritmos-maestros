extends Control
class_name Splash

## Splash screen con animacion de frames PNG.
##
## - Modo `play_once = true` (default): dura SHORT_DURATION segundos y marca `boot_seen` en settings.
## - Modo `play_once = false`: reproduce la animacion completa con safety timer.
## - Skip siempre disponible con Escape, Enter o click.

const FRAMES_DIR := "res://assets/video/splash_frames"
const FRAME_PREFIX := "frame_"
const FRAME_EXT := ".png"
const FRAME_RATE_FPS: float = 8.0
const SHORT_DURATION: float = 1.2
const FULL_DURATION_MAX: float = 10.0
const SAFETY_TIMEOUT: float = 30.0
const FADE_OUT_DURATION := 0.4
const DEFAULT_MUSIC_VOLUME_DB := -10.0

signal splash_finished
signal splash_failed(reason: String)

@export var play_once: bool = true

@onready var texture_rect: TextureRect = $TextureRect
@onready var safety_timer: Timer = $SafetyTimer
@onready var frame_timer: Timer = $FrameTimer
@onready var status_label: Label = $StatusLabel

var _is_finishing: bool = false
var _saved_music_db: float = DEFAULT_MUSIC_VOLUME_DB
var _frames: Array[Texture2D] = []
var _current_frame: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	print("[Splash] _ready() (play_once=%s)" % play_once)
	_set_status("loading splash...")
	_mute_music_bus(true)
	safety_timer.timeout.connect(_on_safety_timeout)
	safety_timer.start(SAFETY_TIMEOUT)
	frame_timer.timeout.connect(_advance_frame)
	frame_timer.wait_time = 1.0 / FRAME_RATE_FPS
	_load_frames()
	# Si play_once, autodisparar fin tras SHORT_DURATION.
	if play_once:
		await get_tree().create_timer(SHORT_DURATION).timeout
		if not _is_finishing:
			_request_finish()

func _load_frames() -> void:
	var frame_paths: PackedStringArray = _discover_frames()
	if frame_paths.is_empty():
		# Sin frames: terminar inmediatamente.
		print("[Splash] no frames; finishing immediately.")
		await get_tree().create_timer(0.05).timeout
		_request_finish()
		return
	_frames.clear()
	for i in range(frame_paths.size()):
		var tex: Resource = load(frame_paths[i])
		if tex == null or not (tex is Texture2D):
			_fail("frame %d not a Texture2D" % i)
			return
		_frames.append(tex as Texture2D)
	_current_frame = 0
	texture_rect.texture = _frames[0]
	frame_timer.start()
	_set_status("playing... (%d frames)" % _frames.size())
	print("[Splash] animation loaded: %d frames @ %.1f fps" % [_frames.size(), FRAME_RATE_FPS])

func _advance_frame() -> void:
	if _frames.is_empty():
		return
	_current_frame = (_current_frame + 1) % _frames.size()
	texture_rect.texture = _frames[_current_frame]

func _discover_frames() -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(1, 1000):
		var p := "%s/%s%04d%s" % [FRAMES_DIR, FRAME_PREFIX, i, FRAME_EXT]
		if not ResourceLoader.exists(p):
			break
		out.append(p)
	return out

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg

func _fail(reason: String) -> void:
	_set_status("SPLASH FAILED: " + reason)
	push_error("[Splash] " + reason)
	splash_failed.emit(reason)
	safety_timer.stop()

func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_request_finish()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		_request_finish()
		get_viewport().set_input_as_handled()

func _request_finish() -> void:
	if _is_finishing:
		return
	_on_animation_finished()

func _on_safety_timeout() -> void:
	_on_animation_finished()

func _on_animation_finished() -> void:
	if _is_finishing:
		return
	_is_finishing = true
	safety_timer.stop()
	frame_timer.stop()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	await tween.finished
	_mute_music_bus(false)
	if play_once:
		var settings := SaveManager.load_settings()
		settings["boot_seen"] = true
		SaveManager.save_settings(settings)
	splash_finished.emit()
	if is_inside_tree():
		queue_free()

func _mute_music_bus(mute: bool) -> void:
	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		AudioServer.add_bus()
		music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus_idx, "Music")
	if mute:
		_saved_music_db = AudioServer.get_bus_volume_db(music_bus_idx)
		AudioServer.set_bus_volume_db(music_bus_idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(music_bus_idx, _saved_music_db)

static func should_show() -> bool:
	var settings := SaveManager.load_settings()
	return not bool(settings.get("boot_seen", false))