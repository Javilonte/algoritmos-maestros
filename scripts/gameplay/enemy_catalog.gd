extends RefCounted
class_name EnemyCatalog

## Catálogo de enemigos con vulnerabilidades elementales.
## Cada enemigo tiene un dict {display_name, max_hp, element_weaknesses, xp_reward}.

const CATALOG: Dictionary = {
	"slime_aritm": {
		"display_name": "Slime Aritmético",
		"max_hp": 60,
		"respawn_time": 25.0,
		"challenge_id": "slime_aritm",
		"element_weaknesses": {"arithmetic": 2.0, "control_flow": 1.0},
		"xp_reward": 50,
		"flavor": "Resistente a la confusión; vulnerable a operaciones básicas.",
		"is_boss": false,
		"color": Color(0.5, 0.9, 0.5),
	},
	"buggo_ciego": {
		"display_name": "Buggo Ciego",
		"max_hp": 80,
		"respawn_time": 30.0,
		"challenge_id": "buggo_ciego",
		"element_weaknesses": {"control_flow": 2.5, "arithmetic": 1.0},
		"xp_reward": 80,
		"flavor": "Si tu rama 'else' no se ejecuta, esquiva el golpe.",
		"is_boss": false,
		"color": Color(0.9, 0.7, 0.3),
	},
	"ogro_bucle": {
		"display_name": "Ogro del Bucle Infinito",
		"max_hp": 100,
		"respawn_time": 35.0,
		"challenge_id": "ogro_bucle",
		"element_weaknesses": {"control_flow": 2.0, "stl": 1.5},
		"xp_reward": 120,
		"flavor": "Si tu for no termina, él sigue vivo.",
		"is_boss": false,
		"color": Color(0.6, 0.4, 0.3),
	},
	"fantasma_offbyone": {
		"display_name": "Fantasma Off-by-One",
		"max_hp": 90,
		"respawn_time": 30.0,
		"challenge_id": "fantasma_offbyone",
		"element_weaknesses": {"pointer": 2.0, "control_flow": 1.2},
		"xp_reward": 110,
		"flavor": "Un índice fuera de lugar lo atraviesa.",
		"is_boss": false,
		"color": Color(0.7, 0.7, 0.95),
	},
	"memory_leak": {
		"display_name": "Jefe: Memory Leak",
		"max_hp": 250,
		"respawn_time": 60.0,
		"challenge_id": "memory_leak",
		"element_weaknesses": {"pointer": 3.0},
		"xp_reward": 400,
		"flavor": "No lo hieres si no liberas la memoria.",
		"is_boss": true,
		"color": Color(1.0, 0.2, 0.2),
	},
	"hidra_recursiva": {
		"display_name": "Hidra Recursiva",
		"max_hp": 180,
		"respawn_time": 50.0,
		"challenge_id": "hidra_recursiva",
		"element_weaknesses": {"control_flow": 2.5},
		"xp_reward": 280,
		"flavor": "Cada llamada recursiva le corta una cabeza.",
		"is_boss": false,
		"color": Color(0.5, 0.8, 0.4),
	},
	"golem_generico": {
		"display_name": "Golem Genérico",
		"max_hp": 150,
		"respawn_time": 45.0,
		"challenge_id": "golem_generico",
		"element_weaknesses": {"template": 2.5},
		"xp_reward": 250,
		"flavor": "Resistente a tipos concretos; usa templates.",
		"is_boss": false,
		"color": Color(0.7, 0.6, 0.5),
	},
	"dragon_caos": {
		"display_name": "Dragón del Caos",
		"max_hp": 220,
		"respawn_time": 55.0,
		"challenge_id": "dragon_caos",
		"element_weaknesses": {"stl": 2.5, "control_flow": 1.5},
		"xp_reward": 350,
		"flavor": "Desordena vectores; std::sort lo calma.",
		"is_boss": false,
		"color": Color(0.95, 0.3, 0.3),
	},
	"wyrm_paralelo": {
		"display_name": "Wyrm Paralelo",
		"max_hp": 260,
		"respawn_time": 60.0,
		"challenge_id": "wyrm_paralelo",
		"element_weaknesses": {"concurrency": 3.0},
		"xp_reward": 450,
		"flavor": "Solo muere si todos los hilos completan.",
		"is_boss": false,
		"color": Color(0.95, 0.85, 0.3),
	},
	"compilador_divino": {
		"display_name": "Jefe Final: Compilador Divino",
		"max_hp": 500,
		"respawn_time": 120.0,
		"challenge_id": "compilador_divino",
		"element_weaknesses": {"pointer": 2.0, "stl": 2.0, "template": 2.0, "concurrency": 2.0},
		"xp_reward": 1500,
		"flavor": "Solo #include <bits/stdc++.h> lo abate.",
		"is_boss": true,
		"color": Color(1.0, 0.95, 0.6),
	},
}

static func fetch(id: String) -> Dictionary:
	if not CATALOG.has(id):
		return {}
	return CATALOG[id]

static func list_all() -> Array:
	return CATALOG.keys()

static func list_for_level(level: int) -> Array:
	## Devuelve IDs de enemigos cuyo challenge_id mínimo <= level.
	## Para esta versión simple: nivel >= N desbloquea enemigo N.
	var mapping := {
		1: ["slime_aritm"],
		2: ["buggo_ciego"],
		3: ["ogro_bucle"],
		4: ["fantasma_offbyone"],
		5: ["memory_leak"],
		6: ["hidra_recursiva"],
		7: ["golem_generico"],
		8: ["dragon_caos"],
		9: ["wyrm_paralelo"],
		10: ["compilador_divino"],
	}
	var out: Array = []
	for lvl in mapping:
		if lvl <= level:
			out.append_array(mapping[lvl])
	return out