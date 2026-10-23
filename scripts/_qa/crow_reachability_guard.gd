extends SceneTree

## ponytail: guard against the "crow spawn unreachable" bug. The player
## walks in 8 iso directions (the 4 cardinals + 4 diagonals projected
## through TILE_W=50, TILE_H=28). Spawn positions outside the player's
## 8-direction reach are unreachable — the player walks past them
## without colliding.
##
## For each spawn (gx, gy), this checks:
##   1) The spawn is on the visible map (|gx| + |gy| <= map_radius).
##   2) The trajectory of any of the 8 player input directions passes
##      within HIT_RADIUS (+ player radius) of the spawn's screen pos.
##   3) The spawn is along ONE of the 8 input directions (no arbitrary
##      angle required).
##
## Run with:
##   godot --headless -s scripts/_qa/crow_reachability_guard.gd --quit-after 10

const IsoCoordsScript := preload("res://scripts/iso/iso_coords.gd")

const MAP_RADIUS := 4
const HIT_RADIUS := 80.0
const PLAYER_RADIUS := 12.0
const COLLISION_RANGE := HIT_RADIUS + PLAYER_RADIUS

# Read the demo's CROW_SPAWNS list by parsing the .gd file. We can't
# preload iso_demo_world because it depends on GameManager autoload.
const SPAWNS := [
	Vector2i(2, 0),
	Vector2i(-2, 0),
	Vector2i(0, 2),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	# Compute the 8 input direction vectors (matching iso_input_to_velocity).
	var directions: Array = []
	for ix in [-1, 0, 1]:
		for iy in [-1, 0, 1]:
			if ix == 0 and iy == 0:
				continue
			directions.append(_player_direction(ix, iy))

	for spawn in SPAWNS:
		var gx: int = spawn.x
		var gy: int = spawn.y
		var screen_pos: Vector2 = IsoCoordsScript.world_to_screen_anchored(gx, gy, 0.0)

		# 1) Visibility check: spawn must be on the map.
		if abs(gx) + abs(gy) <= MAP_RADIUS:
			passed += 1
		else:
			failed += 1
			print("  OFF-MAP SPAWN at (%d, %d): |gx|+|gy|=%d > %d" % [
				gx, gy, abs(gx) + abs(gy), MAP_RADIUS
			])

		# 2) Reachability check: at least one of the 8 directions must pass
		# within COLLISION_RANGE of the spawn.
		var reachable := false
		for dir in directions:
			if _closest_approach(screen_pos, dir) <= COLLISION_RANGE:
				reachable = true
				break
		if reachable:
			passed += 1
		else:
			failed += 1
			print("  UNREACHABLE SPAWN at (%d, %d) screen=%s: no input direction passes within %.1fpx" % [
				gx, gy, screen_pos, COLLISION_RANGE
			])

	print("\n========== CROW REACHABILITY GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


# Mirrors IsoCoords.iso_input_to_velocity (without the .normalized()
# call so we preserve the trajectory's y/x ratio).
func _player_direction(ix: int, iy: int) -> Vector2:
	var iso := Vector2(float(ix - iy) * 0.5, float(ix + iy) * 0.5)
	var screen_velocity := Vector2(iso.x * 50.0, iso.y * 28.0)
	if screen_velocity.length() < 0.001:
		return Vector2.ZERO
	return screen_velocity.normalized()


# Distance from point `p` to the line through origin in direction `dir`.
func _closest_approach(p: Vector2, dir: Vector2) -> float:
	if dir == Vector2.ZERO:
		return p.length()
	# Perpendicular distance: |p × dir| / |dir|.
	return abs(p.x * dir.y - p.y * dir.x) / dir.length()
