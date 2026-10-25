extends RefCounted

## Nivel 04 — Distrito Neón: El Índice.
##
## Capítulo 04: los arreglos, los límites y el off-by-one. El concepto es
## que el primer índice es 0 y el último es n-1, y el ejercicio es
## `binary_search` (el Fantasma Off-by-One te atraviesa si contás mal).
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
## ponytail: este nivel ENSEÑA el off-by-one con el cuerpo, no con el
## texto. Las plataformas son de una y dos tiles (contarlas es obligatorio:
## el borde derecho es el que importa) y hay DOS estirones de 4, que
## parecen de 3 si contás desde uno. El índice equivocado te deja corto.

const REQUIRES_SKILL := &"ptr_arrays"

const ID := "level_04"
const DISPLAY_NAME := "Distrito Neón: El Índice"
const CHAPTER := "Distrito Neón"

const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 13, "top": 15},      # spawn, llano
	{"x0": 16, "x1": 27, "top": 15},     # hueco 2
	{"x0": 30, "x1": 40, "top": 14},     # hueco 2, subida 1
	{"x0": 43, "x1": 53, "top": 14},     # hueco 2
	{"x0": 56, "x1": 66, "top": 13},     # hueco 2, subida 1
	{"x0": 69, "x1": 80, "top": 13},     # hueco 2
	{"x0": 83, "x1": 92, "top": 12},     # hueco 2, subida 1
	{"x0": 95, "x1": 108, "top": 12},    # hueco 2
	{"x0": 111, "x1": 120, "top": 11},   # hueco 2, subida 1
	{"x0": 123, "x1": 133, "top": 11},   # hueco 2
	{"x0": 138, "x1": 150, "top": 11},   # HUECO 4 — estirón
	{"x0": 153, "x1": 166, "top": 10},   # hueco 2, subida 1
	{"x0": 169, "x1": 180, "top": 10},   # hueco 2
	{"x0": 183, "x1": 194, "top": 10},   # hueco 2
	{"x0": 199, "x1": 225, "top": 10},   # HUECO 4 — estirón, la arena final
]

const FLOATING: Array[Dictionary] = [
	{"x0": 33, "x1": 34, "y": 12},       # dos tiles: hay que contarlos
	{"x0": 45, "x1": 46, "y": 12},
	{"x0": 58, "x1": 60, "y": 11},
	{"x0": 71, "x1": 72, "y": 11},       # una tile
	{"x0": 86, "x1": 88, "y": 10},
	{"x0": 98, "x1": 99, "y": 10},       # una tile
	{"x0": 101, "x1": 103, "y": 10},
	{"x0": 114, "x1": 116, "y": 9},
	{"x0": 141, "x1": 143, "y": 9},      # sobre el primer estirón
	{"x0": 156, "x1": 158, "y": 8},
	{"x0": 172, "x1": 173, "y": 8},      # una tile
	{"x0": 200, "x1": 203, "y": 8},      # sobre el segundo estirón
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "fantasma_offbyone", "y": 15, "patrol": Vector2i(18, 26)},
	{"id": "fantasma_offbyone", "y": 14, "patrol": Vector2i(44, 52)},
	{"id": "fantasma_offbyone", "y": 12, "patrol": Vector2i(96, 107)},
	{"id": "fantasma_offbyone", "y": 10, "patrol": Vector2i(154, 165)},
	{"id": "fantasma_offbyone", "y": 10, "patrol": Vector2i(201, 222)},
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 43, "y": 14},
	{"x": 95, "y": 12},
	{"x": 112, "y": 11},
	{"x": 140, "y": 11},
	{"x": 170, "y": 10},
]

const PLAYER_START := Vector2i(4, 15)
