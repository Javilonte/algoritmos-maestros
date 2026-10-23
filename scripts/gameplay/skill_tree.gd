extends Node
class_name SkillTreeData

## Skill tree ramificado.
##
##         root_arithmetic (Nv.1)
##                 |
##      +----------+----------+
##      |                     |
##  branch_pointers      branch_stl
##      |                     |
##  ptr_lv2 (if/else)   stl_lv2 (for/while)
##      |                     |
##  ptr_lv3 (malloc)    stl_lv3 (vector/sort)
##      |                     |
##  BOSS: memory_leak   BOSS: chaos_dragon
##      |                     |
##      +----------+----------+
##                 |
##         fusion (Nv.6)
##                 |
##  recursion / templates / threads / final_boss

signal xp_changed(current: int, to_next: int)
signal level_changed(level: int)
signal skill_unlocked(skill_id: StringName)
signal skill_locked(skill_id: StringName, reason: String)

const XP_PER_LEVEL_BASE: int = 100
const XP_PER_LEVEL_GROWTH: float = 1.5

var current_xp: int = 0
var current_level: int = 1
var skills: Dictionary = {}  # id -> SkillNode
var _root_id: StringName = &"root_arithmetic"

func _ready() -> void:
	_register_defaults()

func _register_defaults() -> void:
	var defs: Array = [
		{
			"id": _root_id,
			"name": "Aritmética Básica",
			"desc": "Operadores +, -, *, /, %, int, cout",
			"level": 1, "cost": 0,
			"keywords": ["+", "-", "*", "/", "%", "int", "cout"],
			"macros": [], "enemies": ["slime_aritm"], "deps": [],
		},
		{
			"id": &"branch_pointers",
			"name": "Rama Punteros",
			"desc": "Camino ofensivo: punteros y memoria",
			"level": 2, "cost": 100,
			"keywords": ["*", "&", "->"], "macros": [], "enemies": [], "deps": [_root_id],
		},
		{
			"id": &"branch_stl",
			"name": "Rama STL",
			"desc": "Camino táctico: contenedores y algoritmos",
			"level": 2, "cost": 100,
			"keywords": ["std::", "vector"], "macros": ["sort"], "enemies": [], "deps": [_root_id],
		},
		{
			"id": &"ptr_if_else",
			"name": "Control de Flujo",
			"desc": "if / else — predica el resultado",
			"level": 2, "cost": 150,
			"keywords": ["if", "else"], "macros": ["crit"], "enemies": ["buggo_ciego"], "deps": [&"branch_pointers"],
		},
		{
			"id": &"ptr_arrays",
			"name": "Arreglos",
			"desc": "Acceso por índice, off-by-one",
			"level": 3, "cost": 200,
			"keywords": ["[]"], "macros": [], "enemies": ["fantasma_offbyone"], "deps": [&"ptr_if_else"],
		},
		{
			"id": &"ptr_dynamic",
			"name": "Memoria Dinámica",
			"desc": "malloc / free / new / delete",
			"level": 4, "cost": 350,
			"keywords": ["malloc", "free", "new", "delete", "nullptr"],
			"macros": ["free"], "enemies": ["memory_leak"], "deps": [&"ptr_arrays"],
		},
		{
			"id": &"stl_loops",
			"name": "Bucles",
			"desc": "for / while — iteración",
			"level": 2, "cost": 150,
			"keywords": ["for", "while"], "macros": ["loop"], "enemies": ["ogro_bucle"], "deps": [&"branch_stl"],
		},
		{
			"id": &"stl_functions",
			"name": "Funciones",
			"desc": "Definición y reutilización",
			"level": 3, "cost": 200,
			"keywords": ["return"], "macros": [], "enemies": ["golem_generico"], "deps": [&"stl_loops"],
		},
		{
			"id": &"stl_containers",
			"name": "STL Containers",
			"desc": "std::vector, std::sort",
			"level": 4, "cost": 350,
			"keywords": ["std::sort", "std::vector"],
			"macros": ["sort"], "enemies": ["dragon_caos"], "deps": [&"stl_functions"],
		},
		{
			"id": &"fusion",
			"name": "Fusión de Ramas",
			"desc": "Acceso a las técnicas avanzadas",
			"level": 6, "cost": 800,
			"keywords": [], "macros": [], "enemies": [], "deps": [&"ptr_dynamic", &"stl_containers"],
		},
		{
			"id": &"recursion",
			"name": "Recursión",
			"desc": "Funciones que se invocan a sí mismas",
			"level": 6, "cost": 500,
			"keywords": ["return"], "macros": [], "enemies": ["hidra_recursiva"], "deps": [&"fusion"],
		},
		{
			"id": &"templates",
			"name": "Templates",
			"desc": "Programación genérica",
			"level": 7, "cost": 600,
			"keywords": ["template", "typename"], "macros": [], "enemies": [], "deps": [&"fusion"],
		},
		{
			"id": &"concurrency",
			"name": "Concurrencia",
			"desc": "std::thread, async",
			"level": 9, "cost": 900,
			"keywords": ["std::thread", "async"], "macros": [], "enemies": ["wyrm_paralelo"], "deps": [&"templates"],
		},
		{
			"id": &"final_boss",
			"name": "Jefe Final",
			"desc": "Compilador Divino (#include <bits>)",
			"level": 10, "cost": 1500,
			"keywords": ["#include", "bits/stdc++.h"],
			"macros": [], "enemies": ["compilador_divino"], "deps": [&"recursion", &"concurrency"],
		},
	]
	for d in defs:
		var n := SkillNode.new()
		n.id = d["id"]
		n.display_name = d["name"]
		n.description = d["desc"]
		n.required_level = int(d["level"])
		n.cost_xp = int(d["cost"])
		n.keywords = PackedStringArray(d["keywords"])
		n.macros_unlocked = PackedStringArray(d["macros"])
		n.enemies_unlocked = PackedStringArray(d["enemies"])
		n.depends_on = PackedStringArray(d["deps"])
		n.icon_color = _color_for_category(n.id)
		skills[n.id] = n

func _color_for_category(id: StringName) -> Color:
	if id in [&"branch_pointers", &"ptr_if_else", &"ptr_arrays", &"ptr_dynamic"]:
		return Color(0.9, 0.4, 0.4)
	if id in [&"branch_stl", &"stl_loops", &"stl_functions", &"stl_containers"]:
		return Color(0.4, 0.7, 0.95)
	if id in [&"recursion", &"templates"]:
		return Color(0.85, 0.6, 0.95)
	if id == &"concurrency":
		return Color(0.95, 0.85, 0.4)
	if id == &"final_boss":
		return Color(1.0, 0.3, 0.6)
	return Color(0.6, 0.7, 0.8)

## --- API pública ---

func add_xp(amount: int) -> void:
	current_xp += amount
	var needed := _xp_for_next_level()
	# ponytail: track whether the level changed so the signal only fires
	# when the player actually leveled up (avoids spurious "LEVEL UP!" toasts).
	var leveled_up: bool = false
	while current_xp >= needed:
		current_xp -= needed
		current_level += 1
		needed = _xp_for_next_level()
		leveled_up = true
	xp_changed.emit(current_xp, needed)
	if leveled_up:
		level_changed.emit(current_level)

func can_unlock(skill_id: StringName) -> bool:
	if not skills.has(skill_id):
		return false
	var n: SkillNode = skills[skill_id]
	if n.unlocked:
		return false
	if current_level < n.required_level:
		return false
	if current_xp < n.cost_xp:
		return false
	for dep in n.depends_on:
		if not skills.has(dep) or not skills[dep].unlocked:
			return false
	return true

func try_unlock(skill_id: StringName) -> bool:
	if not can_unlock(skill_id):
		var reason := "requirements not met"
		if not skills.has(skill_id):
			reason = "unknown skill"
		skill_locked.emit(skill_id, reason)
		return false
	var n: SkillNode = skills[skill_id]
	n.unlocked = true
	current_xp -= n.cost_xp
	skill_unlocked.emit(n.id)
	xp_changed.emit(current_xp, _xp_for_next_level())
	return true

func get_unlocked_keywords() -> PackedStringArray:
	var out := PackedStringArray()
	for id in skills:
		var n: SkillNode = skills[id]
		if n.unlocked:
			for k in n.keywords:
				out.append(k)
	return out

func get_unlocked_macros() -> PackedStringArray:
	var out := PackedStringArray()
	for id in skills:
		var n: SkillNode = skills[id]
		if n.unlocked:
			for m in n.macros_unlocked:
				out.append(m)
	return out

func get_unlocked_enemies() -> PackedStringArray:
	var out := PackedStringArray()
	for id in skills:
		var n: SkillNode = skills[id]
		if n.unlocked:
			for e in n.enemies_unlocked:
				out.append(e)
	return out

func is_keyword_available(keyword: String) -> bool:
	for k in get_unlocked_keywords():
		if k == keyword:
			return true
	return false

func _xp_for_next_level() -> int:
	return int(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, current_level - 1))

func save_state() -> Dictionary:
	var unlocked_ids: Array = []
	for id in skills:
		if (skills[id] as SkillNode).unlocked:
			unlocked_ids.append(id)
	return {
		"current_xp": current_xp,
		"current_level": current_level,
		"unlocked": unlocked_ids,
	}

func load_state(data: Dictionary) -> void:
	if data == null:
		return
	current_xp = int(data.get("current_xp", 0))
	current_level = int(data.get("current_level", 1))
	for id in skills:
		(skills[id] as SkillNode).unlocked = false
	for id in data.get("unlocked", []):
		if skills.has(id):
			(skills[id] as SkillNode).unlocked = true
	xp_changed.emit(current_xp, _xp_for_next_level())
	level_changed.emit(current_level)
