extends RefCounted

## Nivel 07 — Distrito Neón: La Recursión.
##
## Capítulo 07: la recursión. El concepto es el caso base y la
## memoización, y los ejercicios son `fibonacci` y `simple_dp`: la Hidra
## Recursiva pelea primero con Fibonacci y, si la vencés, vuelve con la
## versión iterativa del mismo problema.
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
## ponytail: la Hidra es un enemigo de DOS FASES. `challenge_id_next` en
## el catálogo es su segundo ejercicio: cuando la vencés no desaparece,
## cambia de challenge y sigue en la arena. La segunda pelea es el mismo
## problema resuelto de otra forma: recursivo y despues iterativo.

const REQUIRES_SKILLS: Array[StringName] = [&"recursion"]

const ID := "level_07"
const DISPLAY_NAME := "Distrito Neón: La Recursión"
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
	{"x0": 115, "x1": 126, "top": 11},   # hueco 2, subida 1
	{"x0": 131, "x1": 142, "top": 11},   # HUECO 4 — estirón
	{"x0": 145, "x1": 158, "top": 11},   # hueco 2
	{"x0": 161, "x1": 200, "top": 11},   # LA ARENA DE LA HIDRA
]

const FLOATING: Array[Dictionary] = [
	{"x0": 36, "x1": 39, "y": 12},
	{"x0": 50, "x1": 52, "y": 12},
	{"x0": 64, "x1": 67, "y": 11},
	{"x0": 78, "x1": 80, "y": 11},
	{"x0": 92, "x1": 95, "y": 10},
	{"x0": 106, "x1": 108, "y": 10},
	{"x0": 118, "x1": 120, "y": 9},
	{"x0": 148, "x1": 151, "y": 9},
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "hidra_recursiva", "y": 11, "patrol": Vector2i(166, 196)},
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 48, "y": 14},
	{"x": 90, "y": 12},
	{"x": 162, "y": 11},
]

const PLAYER_START := Vector2i(4, 15)
