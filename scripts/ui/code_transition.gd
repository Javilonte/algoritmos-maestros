extends Control

## Pantalla de carga: transicion entre el menu y el mundo.
##
## ponytail: el diseño neón vive en `CyberStyleBox`; esta pantalla solo lo
## consume. Antes usaba el tema global de Diablo II (panel marron, [OK]
## verdes) y se leia como otra paleta dentro de un juego que ya es
## cyberpunk de punta a punta.
##
## Boot sequence: tres lineas de log (no mas), typewriter, barra de
## progreso, barrida de scanline y marco HUD. Al terminar, fundido a la
## escena del mundo.

const WORLD_SCENE_PATH := "res://scenes/platformer/platformer_world.tscn"

## Tres lineas y ninguna mas: esto es una transicion, no un informe.
const LOG_LINES: Array[String] = [
	"restaurando partida",
	"inicializando tree-sitter",
	"listo",
]

## Bloque de cursor. JetBrains Mono lo trae; los emojis no.
const CURSOR: String = "█"

## Godot 4 no tiene el tag BBCode [blink]: se imprimia literal en el log.
## El cursor parpadea con un timer, como el del menu principal.
const CURSOR_BLINK: float = 0.45

const SWEEP_SPEED: float = 240.0
const FADE_SPEED: float = 2.4
const GRID_STEP: float = 48.0
const BRACKET_INSET: float = 20.0
const BRACKET_ARM: float = 44.0

## ponytail: el guard de QA necesita una instancia viva para assertear que
## el typewriter avanza, asi que la pantalla no puede cambiar de escena
## sola. El juego nunca toca este flag.
@export var auto_advance: bool = true

@onready var sweep: ColorRect = $Sweep
@onready var type_timer: Timer = $TypeTimer
@onready var cursor_timer: Timer = $CursorTimer
@onready var log_label: RichTextLabel = $Panel/Padding/Column/Log
@onready var progress: ProgressBar = $Panel/Padding/Column/Progress
@onready var pct_label: Label = $Panel/Padding/Column/HeaderRow/PctLabel

var _line: int = 0
var _char: int = 0
var _typing: bool = false
var _waiting: bool = false
var _wait: float = 0.0
var _finished: bool = false
var _fading: bool = false
var _fade: float = 0.0
var _sweep_y: float = -4.0
var _total_chars: int = 0
var _cursor_on: bool = true


func _ready() -> void:
	for line in LOG_LINES:
		_total_chars += line.length()
	_apply_style()
	type_timer.wait_time = GameConstants.TYPEWRITER_CHAR_DELAY
	type_timer.timeout.connect(_on_type_timer_timeout)
	cursor_timer.wait_time = CURSOR_BLINK
	cursor_timer.timeout.connect(_on_cursor_timer_timeout)
	_start_line()


## Los styleboxes neón salen de `CyberStyleBox`; los colores fijos de los
## labels viven en la escena.
func _apply_style() -> void:
	var panel: Panel = $Panel
	panel.add_theme_stylebox_override("panel", CyberStyleBox.panel(CyberStyleBox.CYAN))
	var rule: Panel = $Panel/Padding/Column/Rule
	rule.add_theme_stylebox_override("panel", CyberStyleBox.separator())
	progress.add_theme_stylebox_override("background", CyberStyleBox.track())
	progress.add_theme_stylebox_override("fill", CyberStyleBox.fill(CyberStyleBox.CYAN))
	progress.show_percentage = false


func _start_line() -> void:
	if _line >= LOG_LINES.size():
		_finished = true
		return
	_char = 0
	_typing = true
	_render()
	type_timer.start()


func _on_type_timer_timeout() -> void:
	if not _typing:
		return
	var text: String = LOG_LINES[_line]
	if _char < text.length():
		_char += 1
		_render()
		type_timer.start()
		return
	_typing = false
	_line += 1
	# ponytail: `_char` se resetea acá y no en `_start_line`. Si queda
	# con el largo de la linea que acaba de terminar, el progreso suma esa
	# linea dos veces y el porcentaje se pasa del 100% mientras la linea
	# siguiente ni empezo a escribirse.
	_char = 0
	_waiting = true
	if _line < LOG_LINES.size():
		_wait = GameConstants.TYPEWRITER_LINE_DELAY
	else:
		_wait = GameConstants.TYPEWRITER_FINAL_DELAY
	_render()


func _on_cursor_timer_timeout() -> void:
	_cursor_on = not _cursor_on
	_render()


func _process(delta: float) -> void:
	_sweep_y += SWEEP_SPEED * delta
	if _sweep_y > size.y:
		_sweep_y = -4.0
	sweep.position.y = _sweep_y

	if _waiting:
		_wait -= delta
		if _wait <= 0.0:
			_waiting = false
			_start_line()

	if _finished and not _fading:
		_fading = true

	if _fading:
		_fade += delta * FADE_SPEED
		modulate.a = maxf(0.0, 1.0 - _fade)
		if _fade >= 1.0 and auto_advance:
			get_tree().change_scene_to_file(WORLD_SCENE_PATH)


## Redibuja el log completo. Son tres lineas: re-renderizar es mas barato
## que mantener un buffer incremental con BBCode.
## ponytail: `parse_bbcode`, no `text`. Asignar `text` escribe las
## etiquetas tal cual y el log显示出 "[blink]" en pantalla.
func _render() -> void:
	var out: String = ""
	for i in LOG_LINES.size():
		var text: String = LOG_LINES[i]
		var accent: Color = CyberStyleBox.MAGENTA if i == LOG_LINES.size() - 1 else CyberStyleBox.CYAN
		if i < _line:
			# ponytail: la ultima linea se queda en magenta aunque termine:
			# es el remate de la secuencia. Las otras se apagan.
			var done_color: Color = accent if i == LOG_LINES.size() - 1 else CyberStyleBox.TEXT_DIM
			out += "[color=%s]>[/color] [color=%s]%s[/color]\n" % [
				CyberStyleBox.hex(accent), CyberStyleBox.hex(done_color), text]
		elif i == _line:
			out += "[color=%s]>[/color] [color=%s]%s[/color][color=%s]%s[/color]" % [
				CyberStyleBox.hex(accent), CyberStyleBox.hex(accent),
				text.substr(0, _char), CyberStyleBox.hex(accent),
				CURSOR if _cursor_on else " "]
	log_label.parse_bbcode(out)
	_update_progress()


func _update_progress() -> void:
	# ponytail: `_line` es el indice de la linea que se esta escribiendo.
	# Las lineas terminadas van completas y la actual solo por los
	# caracteres escritos. Sumar `_char` siempre contaba dos veces la
	# ultima linea y la barra se pasaba del 100%.
	var typed: int = 0
	for i in mini(_line, LOG_LINES.size()):
		typed += LOG_LINES[i].length()
	if _line < LOG_LINES.size():
		typed += _char
	var ratio: float = float(typed) / float(maxi(_total_chars, 1))
	progress.value = ratio * 100.0
	pct_label.text = "CARGA %03d%%" % int(round(ratio * 100.0))


## Fondo, retícula y marco. Se dibuja en la raiz para no sumar otro nodo
## con su propio script: los hijos se dibujan encima del padre, asi que el
## fondo tiene que salir de aca, no de un Panel detras.
func _draw() -> void:
	var vp: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.008, 0.012, 0.028))
	var dot := Color(CyberStyleBox.CYAN.r, CyberStyleBox.CYAN.g, CyberStyleBox.CYAN.b, 0.05)
	var y: float = GRID_STEP
	while y < vp.y:
		var x: float = GRID_STEP
		while x < vp.x:
			draw_rect(Rect2(x, y, 1.0, 1.0), dot)
			x += GRID_STEP
		y += GRID_STEP
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.35, 0.32, 0.5), false, 2.0)
	_draw_brackets(vp)


## Esquinas en L: el marco HUD sin panel, como en la pantalla de arranque.
func _draw_brackets(vp: Vector2) -> void:
	var col := Color(CyberStyleBox.CYAN.r, CyberStyleBox.CYAN.g, CyberStyleBox.CYAN.b, 0.45)
	var i: float = BRACKET_INSET
	var a: float = BRACKET_ARM
	var r: float = vp.x - BRACKET_INSET
	var b: float = vp.y - BRACKET_INSET
	draw_line(Vector2(i, i), Vector2(i + a, i), col, 2.0)
	draw_line(Vector2(i, i), Vector2(i, i + a), col, 2.0)
	draw_line(Vector2(r - a, i), Vector2(r, i), col, 2.0)
	draw_line(Vector2(r, i), Vector2(r, i + a), col, 2.0)
	draw_line(Vector2(i, b - a), Vector2(i, b), col, 2.0)
	draw_line(Vector2(i, b), Vector2(i + a, b), col, 2.0)
	draw_line(Vector2(r - a, b), Vector2(r, b), col, 2.0)
	draw_line(Vector2(r, b - a), Vector2(r, b), col, 2.0)
