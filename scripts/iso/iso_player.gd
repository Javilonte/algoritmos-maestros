extends CharacterBody2D

# ponytail: 2D CharacterBody2D driven by an AnimatedSprite2D.
# The visual is the cyberpunk character sheet (idle/walk).
#
# Motion-feel rules (FROZEN — no per-frame reactivity):
#   1. Animation switches between "idle" and "walk" with a HYSTERESIS
#      window (must be moving for > 6 frames before switching to walk,
#      and stopped for > 6 frames before switching back to idle).
#   2. Sprite flips horizontally on direction change (frame-stable).
#   3. Squash & stretch uses smoothed velocity, not raw input.
#   4. Vertical bobbing uses a single fixed phase, no per-frame reset.

const IsoCoordsScript = preload("res://scripts/iso/iso_coords.gd")

@export var speed: float = 200.0
@export var friction: float = 1500.0

## Flip hysteresis: how many physics frames the input must stay stable
## before we switch the sprite's facing direction. Prevents flicker when
## the player taps a key.
@export var flip_hysteresis_frames: int = 6
## How strong the squash/stretch effect is. Smaller = subtler.
@export var squash_max: float = 0.12
## Smoothing rate for scale lerp (per second). Higher = snappier.
@export var squash_smoothing: float = 10.0
## Peak vertical bobbing offset (pixels) at full speed.
@export var bob_amplitude: float = 1.5
## Bobbing frequency (Hz) at full speed.
@export var bob_frequency: float = 4.0
## Sprite is 344x320 in source; we display at this fraction of native size.
@export var sprite_scale: float = 0.35

var _input_vector: Vector2 = Vector2.ZERO
var _sprite: AnimatedSprite2D
var _rest_position: Vector2

# Animation switching with hysteresis.
var _moving_frames: int = 0
var _idle_frames: int = 0
var _current_anim: String = ""

# Direction flip with hysteresis.
var _facing_right: bool = true
var _facing_frames: int = 0

# Smoothed visual state.
var _scale_x: float = 1.0
var _scale_y: float = 1.0
var _move_phase: float = 0.0


func _ready() -> void:
	add_to_group("player")
	z_index = 0
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite:
		_rest_position = _sprite.position
		_scale_x = sprite_scale
		_scale_y = sprite_scale
		_sprite.scale = Vector2(sprite_scale, sprite_scale)


func _physics_process(delta: float) -> void:
	_input_vector = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"),
	)

	if not GameManager.is_player_input_allowed():
		_input_vector = Vector2.ZERO

	var is_moving := _input_vector.length() > 0.001

	if is_moving:
		var screen_velocity := IsoCoordsScript.iso_input_to_velocity(_input_vector)
		velocity = screen_velocity * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_z_sort()
	_update_animation_stable(is_moving, delta)
	_update_visual_state(delta, is_moving)


func _update_animation_stable(is_moving: bool, delta: float) -> void:
	if _sprite == null:
		return
	# Hysteresis-based animation switching: avoid flicker on rapid input
	# changes by only switching once the input has been stable for several
	# physics frames.
	if is_moving:
		_moving_frames += 1
		_idle_frames = 0
	else:
		_idle_frames += 1
		_moving_frames = 0

	var desired: String = "walk" if _moving_frames > flip_hysteresis_frames else "idle"
	if _idle_frames > flip_hysteresis_frames:
		desired = "idle"

	if _current_anim != desired:
		_current_anim = desired
		_sprite.play(desired)


func _update_visual_state(delta: float, is_moving: bool) -> void:
	if _sprite == null:
		return

	# 1) Direction flip with hysteresis: only flip when the input has been
	# pointing the other way for several frames.
	if is_moving:
		var want_right: bool = _input_vector.x >= 0.0
		if want_right != _facing_right:
			_facing_frames += 1
			if _facing_frames >= flip_hysteresis_frames:
				_facing_right = want_right
				_facing_frames = 0
		else:
			_facing_frames = 0
	else:
		_facing_frames = 0

	var target_scale_x: float = sprite_scale * (1.0 if _facing_right else -1.0)
	# Spring toward target (frame-rate independent via delta).
	var k: float = clampf(squash_smoothing * delta, 0.0, 1.0)
	_scale_x = lerp(_scale_x, target_scale_x, k)

	# 2) Squash & stretch based on movement speed.
	var speed_ratio: float = clampf(velocity.length() / max(speed, 1.0), 0.0, 1.0)
	var target_scale_y: float = sprite_scale * (1.0 + squash_max * speed_ratio)
	_scale_y = lerp(_scale_y, target_scale_y, k)

	_sprite.scale = Vector2(_scale_x, _scale_y)

	# 3) Vertical bobbing: single phase, no per-frame reset.
	if is_moving:
		_move_phase += delta * bob_frequency * speed_ratio * TAU
	else:
		_move_phase = move_toward(_move_phase, 0.0, delta * bob_frequency * TAU)
	var bob: float = sin(_move_phase) * bob_amplitude * speed_ratio
	_sprite.position = _rest_position + Vector2(0.0, -bob)


func _update_z_sort() -> void:
	# Higher screen-y = deeper in the map = on top of tiles with lower screen-y.
	z_index = int(global_position.y)
	z_as_relative = false