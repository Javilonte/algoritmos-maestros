class_name GameStateMachine
extends RefCounted

var current_state: int

func _init(initial_state: int) -> void:
	current_state = initial_state

func change_state(new_state: int) -> void:
	if new_state == current_state:
		return
	current_state = new_state

func is_state(state: int) -> bool:
	return current_state == state
