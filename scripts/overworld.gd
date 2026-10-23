extends Node2D

## Overworld: mapa principal donde el jugador se mueve, habla con NPCs
## y entra en batallas.
##
## Controles:
##   WASD / flechas: movimiento
##   Tab: abre el Skill Tree UI (overlay)
##   E: interactuar con NPCs

const SKILL_TREE_UI_PATH := "res://scenes/ui/skill_tree_ui.tscn"

var _skill_tree_ui: Control = null

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	call_deferred("_maybe_show_tutorial")

func _maybe_show_tutorial() -> void:
	if TutorialOverlay.should_show():
		TutorialOverlay.show_if_needed(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_skill_tree"):
		_toggle_skill_tree()
		get_viewport().set_input_as_handled()

func _toggle_skill_tree() -> void:
	if _skill_tree_ui != null and is_instance_valid(_skill_tree_ui):
		_skill_tree_ui.queue_free()
		_skill_tree_ui = null
		return
	if not ResourceLoader.exists(SKILL_TREE_UI_PATH):
		push_error("Overworld: skill_tree_ui.tscn not found at " + SKILL_TREE_UI_PATH)
		return
	var scene: PackedScene = load(SKILL_TREE_UI_PATH)
	_skill_tree_ui = scene.instantiate() as Control
	if _skill_tree_ui == null:
		push_error("Overworld: failed to instantiate SkillTreeUI")
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(_skill_tree_ui)
	add_child(layer)
	_skill_tree_ui.tree_exiting.connect(func() -> void: _skill_tree_ui = null)
