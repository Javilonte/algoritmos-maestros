extends Control

const WORLD_SCENE_PATH := "res://scenes/iso/iso_demo.tscn"

@onready var terminal_text: RichTextLabel = $TerminalPanel/TerminalText
@onready var type_timer: Timer = $TypeTimer

var _lines: Array[String] = [
	"> Compilando mundo...",
	"[color=green][OK][/color] Cargando algoritmos...",
	"[color=green][OK][/color] Generando enemigos...",
	"[color=green][OK][/color] Preparando batalla...",
	"[color=green][OK][/color] Inicializando tree-sitter...",
	"> ¡Listo!",
]
var _header: String = "[color=green]> Algoritmos Maestros OS v0.1.0[/color]\n\n"

var _current_line: int = 0
var _current_char: int = 0
var _current_text: String = ""
var _is_typing: bool = false
var _line_done: bool = false
var _wait_timer: float = 0.0
var _waiting: bool = false
var _all_done: bool = false
var _fading: bool = false
var _fade_progress: float = 0.0

func _ready() -> void:
	terminal_text.clear()
	terminal_text.append_text(_header)
	type_timer.timeout.connect(_on_type_timer_timeout)
	_start_next_line()

func _start_next_line() -> void:
	if _current_line >= _lines.size():
		_all_done = true
		return
	_current_text = _lines[_current_line]
	_current_char = 0
	_is_typing = true
	_line_done = false
	type_timer.start()

func _on_type_timer_timeout() -> void:
	if not _is_typing:
		return
	if _current_char < _current_text.length():
		_current_char += 1
		_update_display()
		type_timer.start()
	else:
		_is_typing = false
		_line_done = true
		terminal_text.append_text("\n")
		_current_line += 1
		_waiting = true
		if _current_line < _lines.size():
			_wait_timer = GameConstants.TYPEWRITER_LINE_DELAY
		else:
			_wait_timer = GameConstants.TYPEWRITER_FINAL_DELAY

func _process(delta: float) -> void:
	if _waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_waiting = false
			_start_next_line()

	if _all_done and not _fading:
		_fading = true

	if _fading:
		_fade_progress += delta * 2.0
		modulate.a = max(0.0, 1.0 - _fade_progress)
		if _fade_progress >= 1.0:
			get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _update_display() -> void:
	terminal_text.clear()
	terminal_text.append_text(_header)
	for i in range(_current_line):
		terminal_text.append_text(_lines[i] + "\n")
	terminal_text.append_text(_current_text.substr(0, _current_char))

func _on_all_lines_done() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)
