class_name CombatStats
extends RefCounted

var max_hp: int
var hp: int

func _init(initial_max_hp: int = 0) -> void:
	max_hp = initial_max_hp
	hp = initial_max_hp

func set_max(new_max_hp: int) -> void:
	max_hp = new_max_hp
	hp = new_max_hp

func reset_to(new_max_hp: int) -> void:
	max_hp = new_max_hp
	hp = new_max_hp

func apply_damage(amount: int) -> void:
	hp = max(0, hp - amount)
