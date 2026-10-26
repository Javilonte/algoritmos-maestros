extends RefCounted

## Nivel 08 — Distrito Neón: Los Hilos.
##
## Capítulo 08: los hilos. El concepto es `template<typename T>` y
## `std::thread`, y los ejercicios son `template_generic` y `thread_join`:
## el Wyrm Paralelo pelea primero con una función genérica y, si lo
## vencés, vuelve con la versión que reparte la cuenta en hilos.
##
## El nivel es DATO, no código: `LevelRegistry` lo indexa y
## `platformer_world.gd` lo pinta. Agregar un nivel es agregar un archivo.
##
## Formato:
##   GROUND_SPANS  {"x0", "x1", "top"}  tramo de suelo; "top" es la fila de
##                   la superficie (menor número = más arriba).
##   FLOATING      {"x0", "x1", "y"}    plataforma flotante.
##   ENEMY_SPOTS   {"id", "y", "patrol"} "id" es del EnemyCatalog, "y" es la
##                   fila donde apoya los pies y "patrol" es el rango x
##                   que recorre (Vector2i del x mínimo al máximo).
##   CHECKPOINTS   {"x", "y"}           punto de respawn; "y" es la fila de
##                   la superficie.
##   PLAYER_START  Vector2i             columna x y fila de superficie.
##
## Invariantes (los asserta scripts/_qa/level_guard.gd contra la física
## real del jugador): hueco <= 3 tiles cómodo, 4 estirón, 5 imposible;
## subida <= 3 tiles; una plataforma a <= 3 tiles del suelo de abajo.
##
## ponytail: segundo capitulo con DOS skills. El nivel se abre con
## cualquiera de los dos y el Wyrm es el enemigo de `concurrency`; su
## segunda fase (`thread_join`) le sale al jugador cuando ya sabe escribir
## una función template. Como en la hidra, vencerlo no lo saca del mapa:
## cambia de challenge y sigue en la arena.

const REQUIRES_SKILLS: Array[StringName] = [&"templates", &"concurrency"]

const ID := "level_08"
const DISPLAY_NAME := "Distrito Neón: Los Hilos"
const CHAPTER := "Distrito Neón"

const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 16, "top": 15},      # spawn, llano
	{"x0": 19, "x1": 30, "top": 15},     # hueco 2
	{"x0": 33, "x1": 44, "top": 14},     # hueco 2, subida 1
	{"x0": 47, "x1": 58, "top": 14},     # hueco 2
	{"x0": 61, "x1": 72, "top": 13},     # hueco 2, subida 1
	{"x0": 75, "x1": 86, "top": 13},     # hueco 2
	{"x0": 89, "x1": 100, "top": 12},    # hueco 2, subida 1
	{"x0": 103, "x1": 112, "top": 12},   # hueco 2
	{"x0": 115, "x1": 124, "top": 11},   # hueco 2, subida 1
	{"x0": 129, "x1": 140, "top": 11},   # HUECO 4 — estirón
	{"x0": 143, "x1": 154, "top": 11},   # hueco 2
	{"x0": 157, "x1": 162, "top": 11},   # hueco 2
	{"x0": 165, "x1": 205, "top": 11},   # LA ARENA DEL WYRM
]

const FLOATING: Array[Dictionary] = [
	{"x0": 36, "x1": 39, "y": 12},
	{"x0": 50, "x1": 52, "y": 12},
	{"x0": 64, "x1": 67, "y": 11},
	{"x0": 78, "x1": 80, "y": 11},
	{"x0": 92, "x1": 95, "y": 10},
	{"x0": 106, "x1": 108, "y": 10},
	{"x0": 117, "x1": 119, "y": 9},
	{"x0": 146, "x1": 149, "y": 9},
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "wyrm_paralelo", "y": 11, "patrol": Vector2i(170, 200)},
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 48, "y": 14},
	{"x": 90, "y": 12},
	{"x": 158, "y": 11},
	{"x": 166, "y": 11},
]

const PLAYER_START := Vector2i(4, 15)
