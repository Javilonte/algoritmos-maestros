extends Node2D
class_name CityBackdrop

## Skyline procedural del distrito neón. Sin assets: los edificios se
## dibujan con `_draw()` en dos capas, cada una con su factor de parallax.
##
## ponytail: es un hijo del mundo (Node2D), no un CanvasLayer. Así hereda
## la transformación de la cámara y la base de los edificios queda clavada
## en la línea del suelo; el parallax es sólo el offset horizontal, que se
## calcula con la cámara a mano. Un CanvasLayer dibujaría en espacio de
## pantalla y el horizonte flotaría cuando el jugador suba.
##
## ponytail: se dibujan sólo los edificios que están en pantalla. Con el
## nivel entero pintado cada frame son ~1800 rects de ventanas por frame
## para nada: el culling lo deja en un par de cientos.

const SEED := 20251025
## Línea del suelo en coordenadas de mundo (fila 15 del nivel).
const BASE_Y: float = 480.0
## Ancho cubierto por el skyline, con margen a cada lado.
const SPAN: float = 9600.0

const LAYERS: Array[Dictionary] = [
	{
		"factor": 0.14,
		"min_h": 70.0, "max_h": 150.0,
		"min_w": 34.0, "max_w": 72.0,
		"color": Color(0.10, 0.07, 0.17),
		"window": Color(0.0, 0.95, 0.85, 0.18),
		"window_density": 0.30,
	},
	{
		"factor": 0.32,
		"min_h": 120.0, "max_h": 250.0,
		"min_w": 50.0, "max_w": 104.0,
		"color": Color(0.035, 0.035, 0.08),
		"window": Color(0.95, 0.25, 0.95, 0.32),
		"window_density": 0.42,
	},
]

var _layers: Array[Dictionary] = []
var _cam_x: float = 0.0


func _ready() -> void:
	_build()


func _process(_delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		_cam_x = cam.global_position.x
	queue_redraw()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_layers = LAYERS.duplicate(true)
	for layer in _layers:
		var buildings: Array[Dictionary] = []
		var x: float = -800.0
		while x < SPAN:
			var w: float = rng.randf_range(float(layer["min_w"]), float(layer["max_w"]))
			var h: float = rng.randf_range(float(layer["min_h"]), float(layer["max_h"]))
			buildings.append({
				"x": x,
				"w": w,
				"h": h,
				"antenna": rng.randf() < 0.25,
			})
			x += w + rng.randf_range(8.0, 30.0)
		layer["buildings"] = buildings


func _draw() -> void:
	for layer in _layers:
		for item in _visible(layer):
			_draw_building(item["building"], item["x"], layer)


## Los edificios de una capa que entran en pantalla, con su x en mundo.
##
## ponytail: el culling va en ESPACIO DE PANTALLA. El backdrop es hijo del
## mundo y hereda la camara, asi que su x esta en coordenadas de mundo;
## compararlo contra el ancho de la viewport descartaba TODOS los
## edificios en cuanto la camara salia del origen y el skyline
## desaparecia a media partida.
func _visible(layer: Dictionary) -> Array:
	var view: Vector2 = get_viewport_rect().size
	var factor: float = float(layer["factor"])
	# El fondo se mueve MÁS LENTO que la cámara: se compensa con el
	# factor (1 - f) sobre la posición de dibujo.
	var offset: float = _cam_x * (1.0 - factor)
	var out: Array = []
	for building in layer["buildings"]:
		var bx: float = float(building["x"]) + offset
		var screen_x: float = bx - _cam_x
		if screen_x + float(building["w"]) < -80.0 or screen_x > view.x + 80.0:
			continue
		out.append({"building": building, "x": bx})
	return out


## Cuantos edificios se ven ahora. Lo usa el guard: con la camara en el
## origen habia Buildings, pero al avanzar desaparecian todos.
func visible_count() -> int:
	var count: int = 0
	for layer in _layers:
		count += _visible(layer).size()
	return count


func _draw_building(building: Dictionary, bx: float, layer: Dictionary) -> void:
	var w: float = float(building["w"])
	var h: float = float(building["h"])
	draw_rect(Rect2(bx, BASE_Y - h, w, h), layer["color"])
	if bool(building["antenna"]):
		draw_rect(Rect2(bx + w * 0.5 - 1.0, BASE_Y - h - 22.0, 2.0, 22.0), layer["color"])
	# Ventanas encendidas.
	var density: float = float(layer["window_density"])
	var cols: int = int(w / 13.0)
	var rows: int = int(h / 17.0)
	for cx in cols:
		for cy in rows:
			if _hash01(float(cx), float(cy), bx) > density:
				continue
			var wx: float = bx + 5.0 + cx * 13.0
			var wy: float = BASE_Y - h + 7.0 + cy * 17.0
			if wx + 4.0 > bx + w:
				continue
			draw_rect(Rect2(wx, wy, 4.0, 6.0), layer["window"])


## Hash determinista por posición: la misma ventana se enciende o no en
## cada frame. Un RNG por frame haría parpadear el skyline.
func _hash01(a: float, b: float, c: float) -> float:
	var v: float = sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
	return v - floor(v)
