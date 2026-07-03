extends Area2D
class_name IsoEnemy

# Tile-space coordinates; iso_world.gd converts these to screen positions.
var tile_position: Vector2i = Vector2i.ZERO

@export var display_name: String = "Iso Goblin"
@export var max_hp: int = 80
@export var challenge_id: String = "main_exit_check"
@export var respawn_time: float = 30.0

@onready var sprite: Node2D = $Sprite
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _is_defeated: bool = false

func _ready() -> void:
	add_to_group("enemies")
	# Convert tile coords to screen coords using iso projection.
	var screen_pos := IsoCoords.world_to_screen_anchored(tile_position.x, tile_position.y, 0.0)
	global_position = screen_pos
	# Snap z-index to world depth.
	z_index = IsoCoords.z_index_for(tile_position.x, tile_position.y)
	if label:
		label.text = display_name
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_defeated:
		return
	if not (body.is_in_group("player") or body.name == "IsoPlayer" or body.name == "Player"):
		return
	var enemy_data: Dictionary = {
		"display_name": display_name,
		"max_hp": max_hp,
		"challenge_id": challenge_id,
		"node": self,
	}
	EventBus.battle_requested.emit(enemy_data)

func defeat() -> void:
	_is_defeated = true
	visible = false
	set_deferred("monitoring", false)
	var timer := get_tree().create_timer(respawn_time)
	timer.timeout.connect(respawn)

func respawn() -> void:
	_is_defeated = false
	visible = true
	monitoring = true