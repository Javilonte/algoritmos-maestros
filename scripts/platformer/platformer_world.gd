extends Node2D
class_name PlatformerWorld

## Mundo del plataformero: construye el nivel, coloca al jugador, spawnea
## enemigos y maneja la camara.
##
## ponytail: el nivel se declara con spans y plataformas, no con un mapa de
## tiles dibujado a mano en el .tscn. Un TileMapLayer serializado es
## ilegible y no se puede diffear; esta lista se lee de un vistazo y se
## edita sin abrir el editor.
##
## ponytail: el nivel tampoco vive acá. `platformer_world.gd` es el mundo
## GENÉRICO y el nivel es un archivo de datos en `data/levels/` que entra
## por `LevelRegistry`. Este script no sabe qué nivel está pintando.

const TILE: int = 32
const LEVEL_ROWS: int = 20
const CAMERA_HEIGHT: float = 110.0
const CAMERA_LOOKAHEAD: float = 90.0
const CAMERA_LERP: float = 7.0
## Fila del plano de muerte: una fila más abajo del fondo del nivel.
const DEATH_ROW: int = LEVEL_ROWS + 1
const DEATH_Y: float = DEATH_ROW * TILE
const RESPAWN_FADE: float = 0.25

## Id del nivel a pintar. La pantalla de selección lo cambia; por defecto
## el primero.
@export var level_id: String = "level_01"

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities
@onready var player: PlatformerPlayer = $Entities/Player
@onready var camera: Camera2D = $Camera2D
@onready var fade: ColorRect = $Fade

var _level: Dictionary = {}
var _level_width: int = 0
var _respawn_point: Vector2 = Vector2.ZERO
var _respawning: bool = false


func _ready() -> void:
	# Mismo patron que el resto de mundos (iso_demo_world, overworld,
	# iso_dungeon): el mundo es quien abre el estado OVERWORLD, no la
	# escena que lo carga. El player exige ese estado para recibir input.
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	_level = LevelRegistry.get_level(level_id)
	if _level.is_empty():
		push_error("PlatformerWorld: unknown level '%s'" % level_id)
		return
	_build_tileset()
	_paint_level()
	_place_player()
	_spawn_enemies()
	_spawn_checkpoints()
	_level_width = _compute_level_width()


## El punto de reaparición: el último checkpoint tocado, o el spawn.
func get_respawn_point() -> Vector2:
	return _respawn_point


func _build_tileset() -> void:
	var built := SideTilesetBuilder.build()
	ground.tile_set = built[0]


## Pinta suelo y plataformas. La fila de superficie usa ground_top (con el
## borde iluminado) y el relleno usa ground_fill.
func _paint_level() -> void:
	for span in _level.get("ground", []):
		var x0: int = int(span["x0"])
		var x1: int = int(span["x1"])
		var top: int = int(span["top"])
		for x in range(x0, x1 + 1):
			ground.set_cell(Vector2i(x, top), 0, _atlas(SideTilesetBuilder.T_GROUND_TOP))
			for y in range(top + 1, LEVEL_ROWS):
				ground.set_cell(Vector2i(x, y), 0, _atlas(SideTilesetBuilder.T_GROUND_FILL))
	for plat in _level.get("floating", []):
		var px0: int = int(plat["x0"])
		var px1: int = int(plat["x1"])
		var py: int = int(plat["y"])
		for x in range(px0, px1 + 1):
			ground.set_cell(Vector2i(x, py), 0, _atlas(SideTilesetBuilder.T_BLOCK))


func _atlas(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % SideTilesetBuilder.ATLAS_COLS, tile_id / SideTilesetBuilder.ATLAS_COLS)


## El jugador apoya los pies en la fila de superficie: su origen (los pies)
## queda en `y * TILE`.
func _place_player() -> void:
	var start: Vector2i = _level.get("player_start", Vector2i(4, 15))
	_respawn_point = Vector2(start.x * TILE + TILE / 2, start.y * TILE)
	player.global_position = _respawn_point


func _spawn_enemies() -> void:
	var scene: PackedScene = load("res://scenes/platformer/platformer_enemy.tscn") as PackedScene
	if scene == null:
		push_error("PlatformerWorld: could not load platformer_enemy.tscn")
		return
	for spot in _level.get("enemies", []):
		# El nivel declara el id del catálogo; nombre, HP y challenge salen
		# del catálogo, no del nivel. Hoy el nivel duplicaba los nombres a
		# mano y dos no coincidían con el catálogo.
		var enemy_id: String = String(spot.get("id", ""))
		var data: Dictionary = EnemyCatalog.fetch(enemy_id)
		if data.is_empty():
			push_warning("PlatformerWorld: unknown enemy id '%s'" % enemy_id)
			continue
		var enemy: Node = scene.instantiate()
		enemy.set("display_name", String(data.get("display_name", "Enemy")))
		enemy.set("max_hp", int(data.get("max_hp", 60)))
		enemy.set("challenge_id", String(data.get("challenge_id", "main_exit_check")))
		enemy.set("enemy_id", enemy_id)
		var patrol: Vector2i = spot.get("patrol", Vector2i.ZERO)
		enemy.set("patrol_min_x", patrol.x * TILE + TILE / 2)
		enemy.set("patrol_max_x", patrol.y * TILE + TILE / 2)
		var spawn_x: int = int(round((patrol.x + patrol.y) * 0.5))
		enemy.global_position = Vector2(spawn_x * TILE + TILE / 2, int(spot["y"]) * TILE)
		entities.add_child(enemy)


func _spawn_checkpoints() -> void:
	var scene: PackedScene = load("res://scenes/platformer/checkpoint.tscn") as PackedScene
	if scene == null:
		push_error("PlatformerWorld: could not load checkpoint.tscn")
		return
	for spot in _level.get("checkpoints", []):
		var checkpoint: Node = scene.instantiate()
		checkpoint.global_position = Vector2(int(spot["x"]) * TILE + TILE / 2, int(spot["y"]) * TILE)
		entities.add_child(checkpoint)
		checkpoint.connect("activated", _on_checkpoint_activated)


func _on_checkpoint_activated(checkpoint: Node) -> void:
	_respawn_point = checkpoint.get_checkpoint_position()


func _compute_level_width() -> int:
	var width: int = 0
	for span in _level.get("ground", []):
		width = maxi(width, int(span["x1"]))
	for plat in _level.get("floating", []):
		width = maxi(width, int(plat["x1"]))
	return (width + 2) * TILE


## Camara con lookahead horizontal: mira hacia donde el jugador va, no
## donde esta. El limite vertical keeps el suelo en cuadro.
func _process(delta: float) -> void:
	if player == null:
		return
	if not _respawning and player.global_position.y > DEATH_Y:
		_respawn()
		return
	var lookahead: float = CAMERA_LOOKAHEAD if player.velocity.x > 20.0 else (-CAMERA_LOOKAHEAD if player.velocity.x < -20.0 else 0.0)
	var target := player.global_position + Vector2(lookahead, -CAMERA_HEIGHT)
	target.x = clampf(target.x, TILE * 4, maxf(TILE * 4, _level_width - TILE * 4))
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-CAMERA_LERP * delta))


## Caer al vacío mata y devuelve al jugador al último checkpoint.
func _respawn() -> void:
	_respawning = true
	player.set_physics_process(false)
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 1.0, RESPAWN_FADE)
	await fade_in.finished
	player.global_position = _respawn_point
	player.velocity = Vector2.ZERO
	camera.global_position = _respawn_point + Vector2(0, -CAMERA_HEIGHT)
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 0.0, RESPAWN_FADE)
	await fade_out.finished
	player.set_physics_process(true)
	_respawning = false
