extends RefCounted

## Nivel 02 — Distrito Neón: La Bifurcación.
##
## Capítulo 02: la bifurcación. El concepto es el `if`/`else` y el
## `return` temprano, y el ejercicio es `linear_search` (el Buggo Ciego
## te busca y no te ve: hay que recorrer una lista y decidir en cada paso).
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
## ponytail: el roster es el del CAPÍTULO: solo el Buggo Ciego. El gate
## por skill hace que el nivel se vacie si el roster no corresponde, así
## que un nivel con enemigos de otros capítulos es un nivel que no se
## puede jugar. Cuatro encuentros del mismo concepto: la diferencia con
## el Nivel 01 es el concepto, no la plataforma.

## El skill que habilita este nivel. El gate es el mismo que el de los
## enemigos: el jugador abre el arbol, desbloquea el skill del capitulo y
## el nivel aparece.
const REQUIRES_SKILL := &"ptr_if_else"

const ID := "level_02"
const DISPLAY_NAME := "Distrito Neón: La Bifurcación"
const CHAPTER := "Distrito Neón"

const GROUND_SPANS: Array[Dictionary] = [
	{"x0": 0, "x1": 14, "top": 15},      # spawn, llano
	{"x0": 17, "x1": 30, "top": 15},     # hueco 2
	{"x0": 33, "x1": 46, "top": 14},     # hueco 2, subida 1
	{"x0": 49, "x1": 62, "top": 14},     # hueco 2
	{"x0": 65, "x1": 78, "top": 13},     # hueco 2, subida 1
	{"x0": 81, "x1": 96, "top": 13},     # hueco 2
	{"x0": 99, "x1": 112, "top": 12},    # hueco 2, subida 1
	{"x0": 115, "x1": 126, "top": 12},   # hueco 2
	{"x0": 131, "x1": 144, "top": 12},   # HUECO 4 — estirón
	{"x0": 147, "x1": 162, "top": 12},   # hueco 2
	{"x0": 165, "x1": 190, "top": 12},   # hueco 2, la arena final
]

const FLOATING: Array[Dictionary] = [
	{"x0": 36, "x1": 39, "y": 12},
	{"x0": 42, "x1": 45, "y": 11},
	{"x0": 84, "x1": 87, "y": 11},
	{"x0": 102, "x1": 105, "y": 10},
	{"x0": 118, "x1": 121, "y": 10},
	{"x0": 150, "x1": 153, "y": 10},
	{"x0": 180, "x1": 184, "y": 10},
]

const ENEMY_SPOTS: Array[Dictionary] = [
	{"id": "buggo_ciego", "y": 15, "patrol": Vector2i(20, 29)},
	{"id": "buggo_ciego", "y": 14, "patrol": Vector2i(50, 61)},
	{"id": "buggo_ciego", "y": 13, "patrol": Vector2i(67, 77)},
	{"id": "buggo_ciego", "y": 12, "patrol": Vector2i(167, 176)},
]

const CHECKPOINTS: Array[Dictionary] = [
	{"x": 4, "y": 15},
	{"x": 50, "y": 14},
	{"x": 100, "y": 12},
	{"x": 166, "y": 12},
]

const PLAYER_START := Vector2i(4, 15)
