extends Node

## Procesa eventos que se disparan al final de un diálogo.
## Centraliza la lógica de respuesta post-diálogo para mantener
## el DialogueUI desacoplado de la lógica de negocio.

func process_event(event_type: String, event_data: Dictionary) -> void:
	match event_type:
		GameConstants.EVENT_BATTLE:
			_process_battle_event(event_data)
		GameConstants.EVENT_SCENE_CHANGE:
			_process_scene_change_event(event_data)
		GameConstants.EVENT_ITEM:
			_process_item_event(event_data)
		GameConstants.EVENT_CUSTOM:
			_process_custom_event(event_data)
		_:
			push_warning("DialogueManager: unknown event type '%s'" % event_type)

func _process_battle_event(data: Dictionary) -> void:
	var enemy_data := EnemyData.create(
		String(data.get("display_name", "Enemy")),
		int(data.get("max_hp", GameConstants.DEFAULT_ENEMY_MAX_HP)),
		String(data.get("challenge_id", GameConstants.CHALLENGE_MAIN_EXIT)),
		null,
		String(data.get("enemy_id", "")),
		int(data.get("xp_reward", 50))
	)
	EventBus.battle_requested.emit(enemy_data.to_dict())

func _process_scene_change_event(data: Dictionary) -> void:
	var path: String = String(data.get("scene_path", ""))
	if path.is_empty():
		push_warning("DialogueManager: scene_change event with empty scene_path")
		return
	get_tree().change_scene_to_file(path)

func _process_item_event(data: Dictionary) -> void:
	var item_id: String = String(data.get("item_id", ""))
	var quantity: int = int(data.get("quantity", 1))
	# Preparado para futuro sistema de inventario
	push_warning("DialogueManager: item event received (id=%s, qty=%d) — inventory not implemented" % [item_id, quantity])

func _process_custom_event(data: Dictionary) -> void:
	var callback: String = String(data.get("callback", ""))
	# Preparado para callbacks custom por NPC
	push_warning("DialogueManager: custom event received (callback=%s) — not implemented" % callback)
