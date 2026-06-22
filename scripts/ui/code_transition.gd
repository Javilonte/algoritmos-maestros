extends Control

@onready var terminal_text: RichTextLabel = $TerminalText
@onready var type_timer: Timer = $TypeTimer

var _lines: Array[String] = [
	"> Compilando mundo...",
	"[color=green][OK][/color] Cargando algoritmos...",
	"[color=green][OK][/color] Generando enemigos...",
	"[color=green][OK][/color] Preparando batalla...",
	"[color=green][OK][/color] Inicializando tree-sitter...",
	"> ¡Listo!",
]
var _current_line: int = 0
var _current_char: int = 0
var _current_text: String = ""
var _is_typing: bool = false
var _header: String = "[color=green]> Algoritmos Maestros OS v0.1.0[/color]\n\n"

func _ready() -> void:
	terminal_text.clear()
	terminal_text.append_text(_header)
	type_timer.timeout.connect(_on_type_timer_timeout)
	_start_next_line()

func _start_next_line() -> void:
	if _current_line >= _lines.size():
		_on_all_lines_done()
		return
	_current_text = _lines[_current_line]
	_current_char = 0
	_is_typing = true
	type_timer.start()

func _on_type_timer_timeout() -> void:
	if not _is_typing:
		return
	if _current_char < _current_text.length():
		_current_char += 1
		terminal_text.clear()
		terminal_text.append_text(_header)
		for i in range(_current_line):
			terminal_text.append_text(_lines[i] + "\n")
		terminal_text.append_text(_current_text.substr(0, _current_char))
	else:
		_is_typing = false
		terminal_text.append_text("\n")
		_current_line += 1
		if _current_line < _lines.size():
			await get_tree().create_timer(0.3).timeout
		else:
			await get_tree().create_timer(0.8).timeout
		_start_next_line()

func _on_all_lines_done() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")
