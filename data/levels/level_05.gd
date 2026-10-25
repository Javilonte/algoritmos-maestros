extends RefCounted

## Nivel 05 — Distrito Neón: La Ordenación.
##
## Capítulo 05: la ordenación. El concepto es escribir tu propio sort y,
## después, usar el de la biblioteca. Los ejercicios son `bubble_sort`
## (el Golem Genérico: escribí un orden que funciona con cualquier tipo)
## y `use_std_sort` (el Dragón del Caos: `std::sort` lo calma).
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
## ponytail: es el primer capítulo con DOS skills, así que el nivel se
## abre con uno solo (el de `stl_functions`) y el Dragón aparece DORMIDO
## hasta que se desbloquee `stl_containers`. El jugador ve en el mapa
## que hay un enemigo más al final y que todavía no puede pelearlo.

const REQUIRES_SKILLS: Array[StringName] = [&"stl_functions", &"stl_containers"]

const ID := "level_05"
const DISPLAY_NAME := "Distrito Neón: La Ordenación"
const CHAPTER := "Distrito Neón"

const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 14, "top": 15},      # spawn, llano
	{"x0": 17, "x1": 30, "top": 15},     # hueco 2
	{"x0": 33, "x1": 46, "top": 14},     # hueco 2, subida 1
	{"x0": 49, "x1": 62, "top": 14},     # hueco 2
	{"x0": 65, "x1": 78, "top": 13},     # hueco 2, subida 1
	{"x0": 81, "x1": 94, "top": 13},     # hueco 2
	{"x0": 97, "x1": 108, "top": 12},    # hueco 2, subida 1
	{"x0": 111, "x1": 124, "top": 12},   # hueco 2
	{"x0": 127, "x1": 137, "top": 11},   # hueco 2, subida 1
	{"x0": 142, "x1": 154, "top": 11},   # HUECO 4 — estirón
	{"x0": 157, "x1": 170, "top": 11},   # hueco 2
	{"x0": 173, "x1": 185, "top": 10},   # hueco 2, subida 1
	{"x0": 190, "x1": 201, "top": 10},   # HUECO 4 — estirón
	{"x0": 206, "x1": 219, "top": 10},   # hueco 2
	{"x0": 222, "x1": 235, "top": 10},   # hueco 2
	{"x0": 238, "x1": 262, "top": 10},   # hueco 2, la arena final
]

const FLOATING: Array[Dictionary] = [
	{"x0": 36, "x1": 39, "y": 12},
	{"x0": 41, "x1": 43, "y": 12},
	{"x0": 52, "x1": 54, "y": 12},
	{"x0": 68, "x1": 71, "y": 11},
	{"x0": 84, "x1": 86, "y": 11},
	{"x0": 100, "x1": 102, "y": 10},
	{"x0": 114, "x1": 116, "y": 10},
	{"x0": 130, "x1": 132, "y": 9},
	{"x0": 145, "x1": 148, "y": 9},
	{"x0": 160, "x1": 162, "y": 9},
	{"x0": 176, "x1": 178, "y": 8},
	{"x0": 193, "x1": 195, "y": 8},
	{"x0": 209, "x1": 212, "y": 8},
	{"x0": 225, "x1": 228, "y": 8},
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "golem_generico", "y": 15, "patrol": Vector2i(19, 29)},
	{"id": "golem_generico", "y": 13, "patrol": Vector2i(82, 93)},
	{"id": "dragon_caos", "y": 12, "patrol": Vector2i(112, 123)},
	{"id": "golem_generico", "y": 11, "patrol": Vector2i(158, 169)},
	{"id": "dragon_caos", "y": 10, "patrol": Vector2i(240, 260)},
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 50, "y": 14},
	{"x": 98, "y": 12},
	{"x": 128, "y": 11},
	{"x": 174, "y": 10},
	{"x": 223, "y": 10},
]

const PLAYER_START := Vector2i(4, 15)
