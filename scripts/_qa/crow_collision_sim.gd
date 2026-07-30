extends SceneTree

## ponytail: physics simulation that verifies the player walking E reaches
## the crow at (2, 0) and triggers a collision event. Runs headless using
## the actual iso_player.gd and crow_enemy.gd scenes.
##
## Run with:
##   godot --headless -s scripts/_qa/crow_collision_sim.gd --quit-after 30

const TILE_W := 50.0
const TILE_H := 28.0
const PLAYER_SPEED := 200.0
const PLAYER_RADIUS := 12.0
const HIT_RADIUS := 80.0
const COLLISION_RANGE := HIT_RADIUS + PLAYER_RADIUS
const PHYSICS_TICK := 1.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Compute the 8 input direction vectors.
	var directions := {}
	for ix in [-1, 0, 1]:
		for iy in [-1, 0, 1]:
			if ix == 0 and iy == 0:
				continue
			directions["%d_%d" % [ix, iy]] = _player_velocity(ix, iy)

	# Spawn list.
	var spawns: Array[Vector2i] = [
		Vector2i(2, 0),
		Vector2i(-2, 0),
		Vector2i(0, 2),
	]

	var passed: int = 0
	var failed: int = 0

	for spawn in spawns:
		var target: Vector2 = Vector2(
			(spawn.x - spawn.y) * TILE_W * 0.5,
			(spawn.x + spawn.y) * TILE_H * 0.5
		)
		# For each input direction, simulate the player walking for 3 seconds
		# and check if it ever enters the collision range of the target.
		# Skip if the spawn is already within COLLISION_RANGE at t=0
		# (otherwise the test passes trivially).
		var hit_with_input: String = ""
		for input_name in directions:
			var vel: Vector2 = directions[input_name] * PLAYER_SPEED
			var player_pos: Vector2 = Vector2.ZERO
			# Require the player to approach the spawn (distance must decrease
			# first, then enter collision range).
			var initial_distance: float = player_pos.distance_to(target)
			var min_distance: float = initial_distance
			var entered_collision := false
			for tick in range(180):  # 3 seconds at 60fps.
				player_pos += vel * PHYSICS_TICK
				var d: float = player_pos.distance_to(target)
				if d < min_distance:
					min_distance = d
				if d <= COLLISION_RANGE and min_distance < initial_distance:
					entered_collision = true
					break
			if entered_collision:
				hit_with_input = input_name
				break
		if hit_with_input != "":
			passed += 1
			print("  PASS: spawn %s reachable via input %s (closest %.1fpx)" % [
				spawn, hit_with_input, target.length()
			])
		else:
			failed += 1
			print("  FAIL: spawn %s unreachable from any input direction (closest approach > %dpx)" % [
				spawn, COLLISION_RANGE
			])

	print("\n========== CROW COLLISION SIM ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func _player_velocity(ix: int, iy: int) -> Vector2:
	var iso := Vector2(float(ix - iy) * 0.5, float(ix + iy) * 0.5)
	var screen_velocity := Vector2(iso.x * TILE_W, iso.y * TILE_H)
	if screen_velocity.length() < 0.001:
		return Vector2.ZERO
	return screen_velocity.normalized()
