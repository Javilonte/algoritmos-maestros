extends SceneTree

## ponytail: pure-math simulation that mirrors the player's velocity vector
## and the crow's hit area, copied from the on-disk .gd files. This is
## NOT a runtime test — it just verifies the math is consistent.
##
## Run with:
##   godot --headless -s scripts/_qa/crow_collision_math.gd --quit-after 10

const TILE_W: float = 50.0
const TILE_H: float = 28.0
const PLAYER_SPEED: float = 200.0
const PLAYER_RADIUS: float = 12.0
const HIT_RADIUS: float = 80.0  # the new value after the fix
const COLLISION_RANGE: float = HIT_RADIUS + PLAYER_RADIUS
const PHYSICS_TICK: float = 1.0 / 60.0


func _init() -> void:
	# iso_meta has 3 spawns on the E/W/S axes (reachable).
	var spawns: Array[Vector2i] = [
		Vector2i(2, 0),
		Vector2i(-2, 0),
		Vector2i(0, 2),
	]

	# For each spawn, find the input direction that brings the player
	# closest within SIM_SECONDS.
	var passed: int = 0
	var failed: int = 0
	for spawn in spawns:
		var target: Vector2 = _spawn_to_screen(spawn)
		var best_input: String = ""
		var best_distance: float = INF
		for ix in [-1, 0, 1]:
			for iy in [-1, 0, 1]:
				if ix == 0 and iy == 0:
					continue
				var input_name: String = "%d_%d" % [ix, iy]
				var vel: Vector2 = _player_velocity(ix, iy)
				var distance: float = _closest_approach_4s(target, vel)
				if distance < best_distance:
					best_distance = distance
					best_input = input_name
		var reachable: bool = best_distance <= COLLISION_RANGE
		if reachable:
			passed += 1
		else:
			failed += 1
		print("  spawn=%s target=%s best_input=%s closest=%.1fpx reachable=%s" % [
			spawn, target, best_input, best_distance, reachable
		])

	print("\n========== CROW COLLISION MATH ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func _spawn_to_screen(spawn: Vector2i) -> Vector2:
	return Vector2(
		(spawn.x - spawn.y) * TILE_W * 0.5,
		(spawn.x + spawn.y) * TILE_H * 0.5
	)


func _player_velocity(ix: int, iy: int) -> Vector2:
	# Mirrors IsoCoords.iso_input_to_velocity exactly.
	var iso: Vector2 = Vector2(float(ix - iy) * 0.5, float(ix + iy) * 0.5)
	var screen_velocity: Vector2 = Vector2(iso.x * TILE_W, iso.y * TILE_H)
	if screen_velocity.length() < 0.001:
		return Vector2.ZERO
	return screen_velocity.normalized() * PLAYER_SPEED


func _closest_approach_4s(target: Vector2, vel: Vector2) -> float:
	# Simulate the player walking for 4 seconds and return the minimum
	# distance to the target.
	var player_pos: Vector2 = Vector2.ZERO
	var min_dist: float = player_pos.distance_to(target)
	for tick in range(240):
		player_pos += vel * PHYSICS_TICK
		var d: float = player_pos.distance_to(target)
		if d < min_dist:
			min_dist = d
	return min_dist
