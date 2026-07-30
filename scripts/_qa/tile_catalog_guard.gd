extends SceneTree

## ponytail: catalog-vs-legacy guard. Asserts the new `cyber_floor_for`
## returns the same Vector2i as the old inline heuristic for every (gx, gy)
## in the playable 9x9 grid. Run with
##   godot --headless -s scripts/_qa/tile_catalog_guard.gd --quit-after 10

const IsoTileCoordsScript := preload("res://scripts/iso/iso_tile_coords.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	# Old heuristic (verbatim from the previous iso_demo_world.gd).
	var legacy := func(gx: int, gy: int) -> Vector2i:
		var dx: int = abs(gx)
		var dy: int = abs(gy)
		var max_d: int = max(dx, dy)
		var parity: int = (gx + gy) % 2
		if max_d == 0:
			return Vector2i(0, 0)
		if max_d == 1:
			return Vector2i(0 if parity == 0 else 1, 0)
		if max_d == 2:
			return Vector2i(2 if parity == 0 else 3, 0)
		if max_d == 3:
			return Vector2i(0 if parity == 0 else 1, 1)
		return Vector2i(2 if parity == 0 else 3, 1)

	for gy in range(-4, 5):
		for gx in range(-4, 5):
			var expected: Vector2i = legacy.call(gx, gy)
			var got: Vector2i = IsoTileCoordsScript.cyber_floor_for(gx, gy)
			if got == expected:
				passed += 1
			else:
				failed += 1
				print("  MISMATCH at (%d,%d): expected=%s got=%s" % [gx, gy, expected, got])

	# Catalog constants must be locked.
	# QA render's old (wrong) aliases kept as backward-compat. The semantic
	# names point to the actual 8 tiles of the atlas.
	var checks: Array = [
		# Semantic names → actual atlas coords.
		[IsoTileCoordsScript.CYBER_FLOOR_PLAIN, Vector2i(0, 0)],
		[IsoTileCoordsScript.CYBER_FLOOR_RUBBLE, Vector2i(1, 0)],
		[IsoTileCoordsScript.CYBER_FLOOR_PIPE_L, Vector2i(2, 0)],
		[IsoTileCoordsScript.CYBER_FLOOR_PIPE_R, Vector2i(3, 0)],
		[IsoTileCoordsScript.CYBER_FLOOR_BROKEN_EARTH, Vector2i(0, 1)],
		[IsoTileCoordsScript.CYBER_CORNER_WALL, Vector2i(1, 1)],
		[IsoTileCoordsScript.CYBER_FLOOR_CRACKED_TOXIC, Vector2i(2, 1)],
		[IsoTileCoordsScript.CYBER_FLOOR_DESTROYED, Vector2i(3, 1)],
		# Backwards-compat aliases — same tile as the semantic name.
		[IsoTileCoordsScript.CYBER_FLOOR_BROKEN_E, IsoTileCoordsScript.CYBER_FLOOR_PIPE_L],
		[IsoTileCoordsScript.CYBER_FLOOR_BROKEN_C, IsoTileCoordsScript.CYBER_FLOOR_PIPE_R],
		[IsoTileCoordsScript.CYBER_FLOOR_MARKED_NE, IsoTileCoordsScript.CYBER_FLOOR_PLAIN],
		[IsoTileCoordsScript.CYBER_FLOOR_DESTROYED_L, IsoTileCoordsScript.CYBER_FLOOR_BROKEN_EARTH],
		[IsoTileCoordsScript.CYBER_FLOOR_GRATE_L, IsoTileCoordsScript.CYBER_FLOOR_CRACKED_TOXIC],
		[IsoTileCoordsScript.CYBER_TOXIC_POOL, IsoTileCoordsScript.CYBER_FLOOR_CRACKED_TOXIC],
		# Extended atlas.
		[IsoTileCoordsScript.EXT_PROP_TREE, Vector2i(0, 7)],
		[IsoTileCoordsScript.EXT_PROP_ROCK, Vector2i(1, 7)],
		[IsoTileCoordsScript.EXT_PROP_BUSH, Vector2i(2, 7)],
		[IsoTileCoordsScript.BRICK_WALL_BOT_N, Vector2i(0, 1)],
		[IsoTileCoordsScript.FLOOR_STONE, Vector2i(0, 0)],
		[IsoTileCoordsScript.DOOR_CLOSED, Vector2i(0, 2)],
	]
	for c in checks:
		if c[0] == c[1]:
			passed += 1
		else:
			failed += 1
			print("  CONSTANT MISMATCH: expected=%s got=%s" % [c[1], c[0]])

	# Helpers.
	if IsoTileCoordsScript.prop_for(&"tree") == IsoTileCoordsScript.EXT_PROP_TREE:
		passed += 1
	else:
		failed += 1
		print("  prop_for('tree') != EXT_PROP_TREE")
	if IsoTileCoordsScript.floor_for_interior("stone") == IsoTileCoordsScript.FLOOR_STONE:
		passed += 1
	else:
		failed += 1
		print("  floor_for_interior('stone') != FLOOR_STONE")

	# QA render pattern: center=(4,4) — must still produce a valid tile.
	for gx in range(9):
		for gy in range(9):
			var t: Vector2i = IsoTileCoordsScript.cyber_floor_for(gx, gy, Vector2i(4, 4))
			if t.x >= 0 and t.x < 4 and t.y >= 0 and t.y < 2:
				passed += 1
			else:
				failed += 1
				print("  QA OUT-OF-BOUNDS at (%d,%d): %s" % [gx, gy, t])

	print("\n========== TILE CATALOG GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)
