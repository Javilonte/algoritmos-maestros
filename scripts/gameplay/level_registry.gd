class_name LevelRegistry

## Índice de niveles jugables.
##
## ponytail: cada nivel es un archivo de datos bajo `data/levels/`, no una
## escena. El mundo y la pantalla de selección leen de acá, así que
## agregar un nivel es agregar un archivo: ni el mundo ni el menú se tocan.
##
## Los datos se leen con `get_script_constant_map()` y no con una property
## por nivel: el mapa de constantes es la única API estable de un GDScript
## leído en runtime, y evita que cada nivel tenga que implementar un
## método propio.

const LEVELS: Array[Dictionary] = [
	{
		"id": "level_01",
		"name": "Distrito Neón: El Umbral",
		"chapter": "Distrito Neón",
		"unlocked": true,
		"script": preload("res://data/levels/level_01.gd"),
	},
	{
		"id": "level_02",
		"name": "Distrito Neón: La Bifurcación",
		"chapter": "Distrito Neón",
		"unlocked": false,
		"script": preload("res://data/levels/level_02.gd"),
	},
]


## Los datos de un nivel, ya normalizados. Dictionary vacío si no existe.
static func get_level(id: String) -> Dictionary:
	var script: GDScript = _script_for(id)
	if script == null:
		push_error("LevelRegistry: unknown level '%s'" % id)
		return {}
	var consts: Dictionary = script.get_script_constant_map()
	return {
		"id": id,
		"name": String(consts.get("DISPLAY_NAME", id)),
		"chapter": String(consts.get("CHAPTER", "")),
		"ground": consts.get("GROUND_SPANS", []),
		"floating": consts.get("FLOATING", []),
		"enemies": consts.get("ENEMY_SPOTS", []),
		"checkpoints": consts.get("CHECKPOINTS", []),
		"player_start": consts.get("PLAYER_START", Vector2i(4, 15)),
		"requires_skill": consts.get("REQUIRES_SKILL", &""),
	}


static func has_level(id: String) -> bool:
	return _script_for(id) != null


static func list_levels() -> Array[Dictionary]:
	return LEVELS.duplicate()


static func get_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in LEVELS:
		out.append(String(entry["id"]))
	return out


static func _script_for(id: String) -> GDScript:
	for entry in LEVELS:
		if String(entry["id"]) == id:
			return entry["script"] as GDScript
	return null
