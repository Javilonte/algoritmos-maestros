extends RefCounted

## Nivel 09 — Distrito Neón: El Compilador.
##
## Capítulo 09: todo junto. El skill es `final_boss` (el último del
## árbol) y el ejercicio es `final_gate`: el Compilador Divino pide un
## `unordered_map`, un `sort` y un bucle, todo en la misma función.
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
## ponytail: el último nivel es el más duro de la plataforma: tres
## estirones de 4 tiles y el suelo cuatro filas más abajo que el spawn.
## El objetivo NO es la plataforma: es la pelea. El Compilador Divino
## tiene 500 de vida y seis turnos de objetivo.

const REQUIRES_SKILLS: Array[StringName] = [&"final_boss"]

const ID := "level_09"
const DISPLAY_NAME := "Distrito Neón: El Compilador"
const CHAPTER := "Distrito Neón"

const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 14, "top": 15},      # spawn, llano
	{"x0": 17, "x1": 28, "top": 15},     # hueco 2
	{"x0": 31, "x1": 42, "top": 14},     # hueco 2, subida 1
	{"x0": 45, "x1": 56, "top": 14},     # hueco 2
	{"x0": 59, "x1": 70, "top": 13},     # hueco 2, subida 1
	{"x0": 73, "x1": 84, "top": 13},     # hueco 2
	{"x0": 87, "x1": 98, "top": 12},     # hueco 2, subida 1
	{"x0": 101, "x1": 112, "top": 12},   # hueco 2
	{"x0": 115, "x1": 124, "top": 11},   # hueco 2, subida 1
	{"x0": 129, "x1": 140, "top": 11},   # HUECO 4 — estirón
	{"x0": 143, "x1": 154, "top": 11},   # hueco 2
	{"x0": 159, "x1": 170, "top": 11},   # HUECO 4 — estirón (a la misma altura)
	{"x0": 173, "x1": 184, "top": 10},   # hueco 2
	{"x0": 189, "x1": 200, "top": 10},   # HUECO 4 — estirón
	{"x0": 203, "x1": 216, "top": 10},   # hueco 2
	{"x0": 219, "x1": 232, "top": 10},   # hueco 2
	{"x0": 235, "x1": 275, "top": 10},   # LA ARENA FINAL
]

const FLOATING: Array[Dictionary] = [
	{"x0": 34, "x1": 37, "y": 12},
	{"x0": 39, "x1": 41, "y": 12},
	{"x0": 48, "x1": 51, "y": 12},
	{"x0": 62, "x1": 65, "y": 11},
	{"x0": 76, "x1": 79, "y": 11},
	{"x0": 90, "x1": 93, "y": 10},
	{"x0": 104, "x1": 107, "y": 10},
	{"x0": 117, "x1": 119, "y": 9},
	{"x0": 132, "x1": 135, "y": 9},
	{"x0": 146, "x1": 149, "y": 9},
	{"x0": 162, "x1": 165, "y": 9},
	{"x0": 176, "x1": 179, "y": 8},
	{"x0": 192, "x1": 195, "y": 8},
	{"x0": 206, "x1": 209, "y": 8},
	{"x0": 222, "x1": 225, "y": 8},
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "compilador_divino", "y": 10, "patrol": Vector2i(240, 272)},   # jefe final
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 46, "y": 14},
	{"x": 88, "y": 12},
	{"x": 130, "y": 11},
	{"x": 174, "y": 10},
	{"x": 236, "y": 10},
]

const PLAYER_START := Vector2i(4, 15)
