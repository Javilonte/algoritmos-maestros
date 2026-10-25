extends RefCounted

## Nivel 03 — Distrito Neón: El Bucle.
##
## Capítulo 03: el bucle. El concepto es el `for`/`while` con un
## ACUMULADOR, y el ejercicio es `factorial` (el Ogro del Bucle Infinito
## se reproduce solo: hay que repetir una cuenta y guardarla).
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
## ponytail: el nivel baja tres filas desde el spawn (15 -> 11) y suma un
## estirón de 4 contra el nivel 02. La plataforma sube a la vez: el
## capítulo del bucle es el primero donde repetir la cuenta importa, y el
## nivel tiene que hacer que repetirla salga a cuenta.

const REQUIRES_SKILLS: Array[StringName] = [&"stl_loops"]

const ID := "level_03"
const DISPLAY_NAME := "Distrito Neón: El Bucle"
const CHAPTER := "Distrito Neón"

const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 14, "top": 15},      # spawn, llano
	{"x0": 17, "x1": 28, "top": 15},     # hueco 2
	{"x0": 31, "x1": 42, "top": 14},     # hueco 2, subida 1
	{"x0": 45, "x1": 58, "top": 14},     # hueco 2
	{"x0": 61, "x1": 74, "top": 13},     # hueco 2, subida 1
	{"x0": 77, "x1": 88, "top": 12},     # hueco 2, subida 1
	{"x0": 91, "x1": 106, "top": 12},    # hueco 2
	{"x0": 109, "x1": 120, "top": 11},   # hueco 2, subida 1
	{"x0": 123, "x1": 134, "top": 11},   # hueco 2
	{"x0": 139, "x1": 150, "top": 11},   # HUECO 4 — estirón
	{"x0": 153, "x1": 168, "top": 11},   # hueco 2
	{"x0": 171, "x1": 186, "top": 11},   # hueco 2
	{"x0": 189, "x1": 215, "top": 11},   # hueco 2, la arena final
]

const FLOATING: Array[Dictionary] = [
	{"x0": 34, "x1": 37, "y": 12},
	{"x0": 39, "x1": 41, "y": 12},
	{"x0": 63, "x1": 66, "y": 11},
	{"x0": 94, "x1": 97, "y": 10},
	{"x0": 100, "x1": 103, "y": 10},
	{"x0": 112, "x1": 115, "y": 9},
	{"x0": 175, "x1": 178, "y": 9},
	{"x0": 206, "x1": 210, "y": 9},
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "ogro_bucle", "y": 15, "patrol": Vector2i(19, 27)},
	{"id": "ogro_bucle", "y": 14, "patrol": Vector2i(47, 57)},
	{"id": "ogro_bucle", "y": 12, "patrol": Vector2i(79, 87)},
	{"id": "ogro_bucle", "y": 11, "patrol": Vector2i(154, 167)},
	{"id": "ogro_bucle", "y": 11, "patrol": Vector2i(191, 200)},
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 46, "y": 14},
	{"x": 92, "y": 12},
	{"x": 124, "y": 11},
	{"x": 172, "y": 11},
]

const PLAYER_START := Vector2i(4, 15)
