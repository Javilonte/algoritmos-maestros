extends Node2D
class_name PlatformerWorld

## Mundo del plataformero: construye el nivel, coloca al jugador, spawnea
## enemigos y maneja la camara.
##
## ponytail: el nivel se declara con spans y plataformas, no con un mapa de
## tiles dibujado a mano en el .tscn. Un TileMapLayer serializado es
## ilegible y no se puede diffear; esta lista se lee de un vistazo y se
## edita sin abrir el editor.

const TILE: int = 32
const LEVEL_ROWS: int = 20
const CAMERA_HEIGHT: float = 110.0
const CAMERA_LOOKAHEAD: float = 90.0
const CAMERA_LERP: float = 7.0

## Tramos de suelo: {"x0": primer tile, "x1": ultimo tile, "top": fila de superficie}.
const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 20, "top": 15},
	{"x0": 24, "x1": 38, "top": 15},
	{"x0": 42, "x1": 60, "top": 13},
	{"x0": 64, "x1": 74, "top": 15},
	{"x0": 78, "x1": 96, "top": 12},
	{"x0": 100, "x1": 124, "top": 15},
]

## Plataformas flotantes: {"x0", "x1", "y"}.
const FLOATING: Array[Dictionary] = [
	{"x0": 8, "x1": 11, "y": 11},
	{"x0": 28, "x1": 32, "y": 10},
	{"x0": 45, "x1": 48, "y": 9},
	{"x0": 52, "x1": 56, "y": 8},
	{"x0": 68, "x1": 71, "y": 11},
	{"x0": 82, "x1": 85, "y": 9},
	{"x0": 88, "x1": 92, "y": 7},
	{"x0": 106, "x1": 110, "y": 11},
	{"x0": 114, "x1": 118, "y": 9},
]

## Enemigos: {"x", "y" (fila del suelo), "name", "challenge", "hp"}.
const ENEMY_SPOTS: Array[Dictionary] = [
	{"x": 16, "y": 15, "name": "Slime Aritmetico", "challenge": "main_exit_check", "hp": 60},
	{"x": 33, "y": 15, "name": "Null Pointer", "challenge": "bubble_sort", "hp": 80},
	{"x": 56, "y": 13, "name": "Fantasma Off-by-One", "challenge": "linear_search", "hp": 70},
	{"x": 72, "y": 15, "name": "Ogro del Bucle", "challenge": "factorial", "hp": 90},
	{"x": 90, "y": 12, "name": "Memory Leak", "challenge": "hash_map", "hp": 120},
	{"x": 118, "y": 15, "name": "Hidra Recursiva", "challenge": "fibonacci", "hp": 110},
]

const PLAYER_START := Vector2i(4, 14)

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities
@onready var player: PlatformerPlayer = $Entities/Player
@onready var camera: Camera2D = $Camera2D

var _level_width: int = 0


func _ready() -> void:
	# Mismo patron que el resto de mundos (iso_demo_world, overworld,
	# iso_dungeon): el mundo es quien abre el estado OVERWORLD, no la
	# escena que lo carga. El player exige ese estado para recibir input.
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	_build_tileset()
	_paint_level()
	_place_player()
	_spawn_enemies()
	_level_width = _compute_level_width()


func _build_tileset() -> void:
	var built := SideTilesetBuilder.build()
	ground.tile_set = built[0]


## Pinta suelo y plataformas. La fila de superficie usa ground_top (con el
## borde iluminado) y el relleno usa ground_fill.
func _paint_level() -> void:
	for span in GROUND_SPANS:
		var x0: int = int(span["x0"])
		var x1: int = int(span["x1"])
		var top: int = int(span["top"])
		for x in range(x0, x1 + 1):
			ground.set_cell(Vector2i(x, top), 0, _atlas(SideTilesetBuilder.T_GROUND_TOP))
			for y in range(top + 1, LEVEL_ROWS):
				ground.set_cell(Vector2i(x, y), 0, _atlas(SideTilesetBuilder.T_GROUND_FILL))
	for plat in FLOATING:
		var px0: int = int(plat["x0"])
		var px1: int = int(plat["x1"])
		var py: int = int(plat["y"])
		for x in range(px0, px1 + 1):
			ground.set_cell(Vector2i(x, py), 0, _atlas(SideTilesetBuilder.T_BLOCK))


func _atlas(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % SideTilesetBuilder.ATLAS_COLS, tile_id / SideTilesetBuilder.ATLAS_COLS)


func _place_player() -> void:
	player.global_position = Vector2(PLAYER_START.x * TILE + TILE / 2, PLAYER_START.y * TILE + TILE)


func _spawn_enemies() -> void:
	var scene: PackedScene = load("res://scenes/platformer/platformer_enemy.tscn") as PackedScene
	if scene == null:
		push_error("PlatformerWorld: could not load platformer_enemy.tscn")
		return
	for spot in ENEMY_SPOTS:
		var enemy: Node = scene.instantiate()
		enemy.set("display_name", String(spot.get("name", "Enemy")))
		enemy.set("max_hp", int(spot.get("hp", 60)))
		enemy.set("challenge_id", String(spot.get("challenge", "main_exit_check")))
		enemy.global_position = Vector2(int(spot["x"]) * TILE + TILE / 2, int(spot["y"]) * TILE)
		entities.add_child(enemy)


func _compute_level_width() -> int:
	var width: int = 0
	for span in GROUND_SPANS:
		width = maxi(width, int(span["x1"]))
	for plat in FLOATING:
		width = maxi(width, int(plat["x1"]))
	return (width + 2) * TILE


## Camara con lookahead horizontal: mira hacia donde el jugador va, no
## donde esta. El limite vertical keeps el suelo en cuadro.
func _process(delta: float) -> void:
	if player == null:
		return
	var lookahead: float = CAMERA_LOOKAHEAD if player.velocity.x > 20.0 else (-CAMERA_LOOKAHEAD if player.velocity.x < -20.0 else 0.0)
	var target := player.global_position + Vector2(lookahead, -CAMERA_HEIGHT)
	target.x = clampf(target.x, TILE * 4, maxf(TILE * 4, _level_width - TILE * 4))
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-CAMERA_LERP * delta))
