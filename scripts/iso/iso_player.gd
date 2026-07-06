extends CharacterBody2D

const IsoCoordsScript = preload("res://scripts/iso/iso_coords.gd")
const IsoCollisionQueryScript = preload("res://scripts/iso/iso_collision_query.gd")

@export var speed: float = 200.0
@export var friction: float = 1500.0
## Frames per second for the idle animation (knight sprite has 4 frames).
@export var idle_fps: float = 4.0
## Scale to apply to the knight sprite. 2.0 = 48x64 pixels in screen space, matching a ~50x56 iso cube.
@export var sprite_scale: float = 2.0

var _input_vector: Vector2 = Vector2.ZERO
var _anim_timer: float = 0.0
var _frame_index: int = 0
var _knight_frames: int = 4


func _ready() -> void:
	add_to_group("player")
	z_index = 0
	_setup_knight_sprite()


func _setup_knight_sprite() -> void:
	## Swap the default teal sprite for the µFantasy knight_blue sprite if available.
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var atlas: AtlasTexture = IsoAtlasBuilder.get_knight_frame_atlas(0, sprite_scale)
	if atlas == null:
		return
	sprite.texture = atlas
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	# Anchor the sprite at the foot bottom-center so it sits on the tile.
	sprite.centered = true
	sprite.position = Vector2(0, 0)
	_knight_frames = IsoAtlasBuilder.KNIGHT_FRAME_COUNT


func _physics_process(_delta: float) -> void:
	_input_vector = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if not GameManager.is_player_input_allowed():
		_input_vector = Vector2.ZERO

	if _input_vector.length() > 0.001:
		var screen_velocity := IsoCoordsScript.iso_input_to_velocity(_input_vector)
		velocity = screen_velocity * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * _delta)

	move_and_slide()
	_update_z_sort()
	_tick_idle_anim(_delta)


func _update_z_sort() -> void:
	# Higher screen-y = deeper in the map = on top of tiles with lower screen-y.
	z_index = int(global_position.y)
	z_as_relative = false


func _tick_idle_anim(delta: float) -> void:
	if _knight_frames <= 1 or idle_fps <= 0.0:
		return
	_anim_timer += delta
	var period := 1.0 / idle_fps
	if _anim_timer < period:
		return
	_anim_timer = 0.0
	_frame_index = (_frame_index + 1) % _knight_frames
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var atlas: AtlasTexture = IsoAtlasBuilder.get_knight_frame_atlas(_frame_index, sprite_scale)
	if atlas != null:
		sprite.texture = atlas