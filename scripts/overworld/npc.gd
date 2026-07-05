extends Area2D
class_name NPC

@export var npc_id: String = ""
@export var display_name: String = "NPC"
@export var dialogue: DialogueData = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var indicator: Node2D = $Indicator

var _player_in_range: bool = false

func _ready() -> void:
	add_to_group("npcs")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if name_label != null:
		name_label.text = display_name
	if indicator != null:
		indicator.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if indicator != null:
			indicator.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if indicator != null:
			indicator.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not _player_in_range:
		return
	if not GameManager.is_state(GameManager.GameState.OVERWORLD):
		return
	if dialogue != null and dialogue.is_valid():
		EventBus.dialogue_requested.emit(npc_id, dialogue)
