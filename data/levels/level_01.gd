extends RefCounted

## Nivel 01 — Distrito Neón: El Umbral.
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
## Invariantes (los asserta scripts/_qa/level_01_guard.gd contra la física
## real del jugador): hueco <= 3 tiles cómodo, 4 estirón, 5 imposible;
## subida <= 3 tiles; una plataforma a <= 3 tiles del suelo de abajo.

## El skill que habilita este nivel. El gate es el mismo que el de los
## enemigos: el jugador abre el arbol, desbloquea el skill del capitulo y
## el nivel aparece. Vacío = el nivel esta disponible desde el arranque.
const REQUIRES_SKILL := &""

const ID := "level_01"
const DISPLAY_NAME := "Distrito Neón: El Umbral"
const CHAPTER := "Distrito Neón"

const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 14, "top": 15},      # spawn, llano
	{"x0": 17, "x1": 28, "top": 15},     # hueco 2
	{"x0": 31, "x1": 50, "top": 14},     # hueco 2, subida 1
	{"x0": 53, "x1": 64, "top": 12},     # hueco 2, subida 2
	{"x0": 67, "x1": 78, "top": 15},     # hueco 2, caída 3
	{"x0": 81, "x1": 110, "top": 13},    # hueco 2, subida 2
	{"x0": 115, "x1": 126, "top": 13},   # HUECO 4 — estirón
	{"x0": 131, "x1": 142, "top": 14},   # HUECO 4, un nivel más abajo
	{"x0": 145, "x1": 155, "top": 14},   # hueco 2
	{"x0": 158, "x1": 166, "top": 12},   # hueco 2, subida 2
	{"x0": 170, "x1": 178, "top": 12},   # hueco 3
	{"x0": 182, "x1": 190, "top": 10},   # hueco 3, subida 2
	{"x0": 194, "x1": 203, "top": 10},   # hueco 3
	{"x0": 206, "x1": 215, "top": 12},   # hueco 2, caída 2
	{"x0": 218, "x1": 245, "top": 12},   # arena del jefe, llana
	{"x0": 248, "x1": 268, "top": 12},   # salida
]

const FLOATING: Array[Dictionary] = [
	{"x0": 20, "x1": 23, "y": 12},
	{"x0": 25, "x1": 27, "y": 13},
	{"x0": 55, "x1": 58, "y": 9},
	{"x0": 60, "x1": 63, "y": 9},
	{"x0": 69, "x1": 72, "y": 12},
	{"x0": 74, "x1": 77, "y": 12},
	{"x0": 85, "x1": 88, "y": 10},
	{"x0": 91, "x1": 94, "y": 10},
	{"x0": 135, "x1": 137, "y": 12},
	{"x0": 160, "x1": 163, "y": 9},
	{"x0": 174, "x1": 177, "y": 9},
	{"x0": 186, "x1": 189, "y": 7},
	{"x0": 197, "x1": 201, "y": 7},
	{"x0": 225, "x1": 228, "y": 9},
	{"x0": 236, "x1": 239, "y": 9},
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "slime_aritm", "y": 15, "patrol": Vector2i(20, 28)},
	{"id": "buggo_ciego", "y": 12, "patrol": Vector2i(56, 64)},
	{"id": "buggo_ciego", "y": 13, "patrol": Vector2i(82, 93)},
	{"id": "fantasma_offbyone", "y": 13, "patrol": Vector2i(100, 109)},
	{"id": "fantasma_offbyone", "y": 14, "patrol": Vector2i(133, 141)},
	{"id": "ogro_bucle", "y": 12, "patrol": Vector2i(158, 166)},
	{"id": "hidra_recursiva", "y": 10, "patrol": Vector2i(182, 190)},
	{"id": "ogro_bucle", "y": 10, "patrol": Vector2i(194, 203)},
	{"id": "golem_generico", "y": 12, "patrol": Vector2i(222, 228)},
	{"id": "memory_leak", "y": 12, "patrol": Vector2i(230, 245)},   # jefe
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 42, "y": 14},
	{"x": 100, "y": 13},
	{"x": 160, "y": 12},
	{"x": 219, "y": 12},
]

const PLAYER_START := Vector2i(4, 15)
