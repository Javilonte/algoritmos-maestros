extends Node2D

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	EventBus.player_spawned.emit($Player)
