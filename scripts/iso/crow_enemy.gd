extends CharacterBody2D
class_name CrowEnemy

# ponytail: crow enemy — same role as the original IsoEnemy but with a
# 2D AnimatedSprite2D, simple patrol AI, and per-state animation. Lives
# on the iso world, walks between waypoints, and triggers a battle when
# the player touches its hitbox.
#
# State machine (frame-stable, hysteresis-based like the player):
#   IDLE    -> WALK when the waypoint timer expires.
#   WALK    -> IDLE when the waypoint is reached.
#   ATTACK  -> triggered externally (battle system) for a short window.
#   HURT    -> short flash when hit by player attack.
#
# Direction flip is smoothed so a single bad frame doesn't cause flicker.

const IsoCoordsScript = preload("res://scripts/iso/iso_coords.gd")

# Tile-space coordinates; iso_demo_world.gd converts these to screen positions.
var tile_position: Vector2i = Vector2i.ZERO

@export var display_name: String = "Cyberpunk Crow"
@export var max_hp: int = 60
@export var challenge_id: String = "main_exit_check"
@export var respawn_time: float = 30.0

# Patrol AI.
@export var patrol_radius: int = 2  # tiles of patrol range
@export var move_speed: float = 80.0
## Seconds spent idle between waypoints.
@export var idle_time: float = 1.5
## Seconds to walk between waypoints.
@export var walk_time: float = 2.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_area: Area2D = $HitArea

var _is_defeated: bool = false
var _state: String = "idle"  # idle | walk | attack | hurt
var _state_timer: float = 0.0
var _home_tile: Vector2i = Vector2i.ZERO
var _target_tile: Vector2i = Vector2i.ZERO
var _facing_right: bool = true
var _facing_frames: int = 0
var _scale_x: float = 1.0
const FLIP_HYSTERESIS: int = 6
const SPRITE_BASE_SCALE: float = 0.35


func _ready() -> void:
	add_to_group("enemies")
	_home_tile = tile_position
	_target_tile = _pick_waypoint()
	# Convert tile coords to local position (parent is IsoDemo, which is
	# positioned at the iso origin in world space). Setting `position`
	# (not `global_position`) keeps the enemy correctly placed under the
	# IsoDemo node.
	var local_pos := IsoCoordsScript.world_to_screen_anchored(tile_position.x, tile_position.y, 0.0)
	position = local_pos
	# Snap z-index to world depth.
	z_index = IsoCoordsScript.z_index_for(tile_position.x, tile_position.y)
	if label:
		label.text = display_name
	_apply_state("idle")
	# Watch for player entry via the dedicated hit area.
	if hit_area:
		hit_area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	_state_timer -= delta
	# Animation flip with hysteresis — only flip after 6 stable frames.
	if abs(velocity.x) > 0.5:
		var want_right: bool = velocity.x >= 0.0
		if want_right != _facing_right:
			_facing_frames += 1
			if _facing_frames >= FLIP_HYSTERESIS:
				_facing_right = want_right
				_facing_frames = 0
		else:
			_facing_frames = 0
	else:
		_facing_frames = 0
	_update_animation()
	_update_sprite_flip(delta)
	move_and_slide()
	_update_z_sort()
	_ai_tick(delta)


func _ai_tick(delta: float) -> void:
	match _state:
		"idle":
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _state_timer <= 0.0:
				_target_tile = _pick_waypoint()
				_apply_state("walk")
		"walk":
			if _state_timer <= 0.0 or _is_at_waypoint():
				_apply_state("idle")
				return
			# Walk towards target tile in local coords (parent is IsoDemo).
			var target_pos := IsoCoordsScript.world_to_screen_anchored(_target_tile.x, _target_tile.y, 0.0)
			var dir: Vector2 = (target_pos - position)
			if dir.length() < 4.0:
				_apply_state("idle")
				return
			velocity = dir.normalized() * move_speed
		"attack":
			velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
			if _state_timer <= 0.0:
				_apply_state("idle")
		"hurt":
			velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
			if _state_timer <= 0.0:
				_apply_state("idle")


func _pick_waypoint() -> Vector2i:
	# Pick a random tile within patrol_radius of home_tile.
	var dx: int = randi_range(-patrol_radius, patrol_radius)
	var dy: int = randi_range(-patrol_radius, patrol_radius)
	return _home_tile + Vector2i(dx, dy)


func _is_at_waypoint() -> bool:
	var target_pos := IsoCoordsScript.world_to_screen_anchored(_target_tile.x, _target_tile.y, 0.0)
	return position.distance_to(target_pos) < 8.0


func _apply_state(new_state: String) -> void:
	if new_state == _state and _state_timer > 0.0:
		return
	_state = new_state
	match _state:
		"idle":
			_state_timer = idle_time
		"walk":
			_state_timer = walk_time
		"attack":
			_state_timer = 0.5
		"hurt":
			_state_timer = 0.3
	_update_animation()


func _update_animation() -> void:
	if sprite == null:
		return
	if sprite.animation != _state:
		sprite.play(_state)


func _update_sprite_flip(delta: float) -> void:
	if sprite == null:
		return
	var target: float = SPRITE_BASE_SCALE * (1.0 if _facing_right else -1.0)
	var k: float = clampf(10.0 * delta, 0.0, 1.0)
	_scale_x = lerp(_scale_x, target, k)
	sprite.scale.x = _scale_x


func _update_z_sort() -> void:
	z_index = int(global_position.y)
	z_as_relative = false


func _on_body_entered(body: Node) -> void:
	if _is_defeated:
		return
	if not (body.is_in_group("player") or body.name == "IsoPlayer" or body.name == "Player"):
		return
	_apply_state("attack")
	var enemy_data: Dictionary = {
		"display_name": display_name,
		"max_hp": max_hp,
		"challenge_id": challenge_id,
		"node": self,
	}
	EventBus.battle_requested.emit(enemy_data)


func take_hit() -> void:
	if _is_defeated:
		return
	_apply_state("hurt")


func defeat() -> void:
	_is_defeated = true
	visible = false
	if hit_area:
		hit_area.set_deferred("monitoring", false)
	var timer := get_tree().create_timer(respawn_time)
	timer.timeout.connect(respawn)


func respawn() -> void:
	_is_defeated = false
	visible = true
	if hit_area:
		hit_area.monitoring = true
	_apply_state("idle")