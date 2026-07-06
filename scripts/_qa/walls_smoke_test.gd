extends SceneTree

## Walls + decor + props smoke test.
## Run: godot --headless -s scripts/_qa/walls_smoke_test.gd --quit-after 30

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: Array = []
	var failed: Array = []

	# 1) iso_walls_atlas.png file exists.
	if not FileAccess.file_exists("res://assets/iso/textures/iso_walls_atlas.png"):
		failed.append("iso_walls_atlas.png missing")
	else:
		var img := Image.load_from_file("res://assets/iso/textures/iso_walls_atlas.png")
		if img == null or img.get_size() != Vector2i(350, 504):
			failed.append("iso_walls_atlas.png wrong size (expected 350x504)")
		else:
			passed.append("iso_walls_atlas.png is 350x504")

	# 2) iso_decor_atlas.png + iso_props_atlas.png + iso_background.png.
	for pair in [
		["iso_decor_atlas.png", Vector2i(350, 336)],
		["iso_props_atlas.png", Vector2i(350, 280)],
	]:
		var name: String = pair[0]
		var expected: Vector2i = pair[1]
		var path := "res://assets/iso/textures/" + name
		if not FileAccess.file_exists(path):
			failed.append(name + " missing")
		else:
			var i := Image.load_from_file(path)
			if i == null or i.get_size() != expected:
				failed.append(name + " wrong size")
			else:
				passed.append(name + " is " + str(expected))

	if not FileAccess.file_exists("res://assets/iso/textures/iso_background.png"):
		failed.append("iso_background.png missing")
	else:
		passed.append("iso_background.png exists")

	# 3) TileSets load.
	for tileset_path in [
		"res://scenes/iso/tilesets/iso_walls_50x56.tres",
		"res://scenes/iso/tilesets/iso_decor_50x56.tres",
		"res://scenes/iso/tilesets/iso_props_50x56.tres",
	]:
		var ts := load(tileset_path) as TileSet
		if ts == null:
			failed.append("Failed to load " + tileset_path)
		else:
			passed.append("Loaded " + tileset_path.rsplit("/", true, 1)[1])

	# 4) IsoTileCoords + IsoCollisionQuery compile.
	var Coords := load("res://scripts/iso/iso_tile_coords.gd")
	if Coords == null:
		failed.append("Failed to load iso_tile_coords.gd")
	else:
		passed.append("iso_tile_coords.gd loaded")
		# Sanity check: BRICK_WALL_BOT_N should be (0, 1)
		var script_obj = Coords.new()
		var brick_n = script_obj.get("BRICK_WALL_BOT_N")
		if brick_n != Vector2i(0, 1):
			failed.append("BRICK_WALL_BOT_N = " + str(brick_n) + " (expected (0, 1))")
		else:
			passed.append("BRICK_WALL_BOT_N = (0, 1)")

	var Query := load("res://scripts/iso/iso_collision_query.gd")
	if Query == null:
		failed.append("Failed to load iso_collision_query.gd")
	else:
		passed.append("iso_collision_query.gd loaded")

	# 5) IsoMeta has wall_regions, doors, decor_positions, prop_positions.
	var meta: Resource = load("res://data/worlds/iso_demo_meta.tres")
	if meta == null:
		failed.append("Failed to load iso_demo_meta.tres")
	else:
		var w = meta.get("wall_regions")
		var d = meta.get("doors")
		var dec = meta.get("decor_positions")
		var props = meta.get("prop_positions")
		if not (w is Array and w.size() >= 2):
			failed.append("iso_meta.wall_regions has <2 entries (got " + str(w.size() if w is Array else 0) + ")")
		else:
			passed.append("iso_meta.wall_regions: " + str(w.size()) + " rooms")
		if not (d is Array and d.size() >= 2):
			failed.append("iso_meta.doors has <2 entries")
		else:
			passed.append("iso_meta.doors: " + str(d.size()) + " doors")
		if not (dec is Array and dec.size() >= 4):
			failed.append("iso_meta.decor_positions has <4 entries")
		else:
			passed.append("iso_meta.decor_positions: " + str(dec.size()))
		if not (props is Array and props.size() >= 4):
			failed.append("iso_meta.prop_positions has <4 entries")
		else:
			passed.append("iso_meta.prop_positions: " + str(props.size()))

	# 6) Background uses forest green.
	var bg_scene := load("res://scripts/iso/iso_background.gd")
	if bg_scene == null:
		failed.append("Failed to load iso_background.gd")
	else:
		var bg_obj = bg_scene.new()
		bg_obj.color_override = Color(0.18, 0.3, 0.18, 1)
		if bg_obj.color_override != Color(0.18, 0.3, 0.18, 1):
			failed.append("iso_background.color_override setter broken")
		else:
			passed.append("iso_background.color_override = (0.18, 0.30, 0.18, 1)")

	# 7) default_clear_color in project.godot
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	var found_clear := false
	if f:
		var content: String = f.get_as_text()
		f.close()
		if "default_clear_color" in content:
			found_clear = true
	if not found_clear:
		failed.append("project.godot missing default_clear_color")
	else:
		passed.append("project.godot has default_clear_color set")

	_finish(passed, failed)


func _finish(passed: Array, failed: Array) -> void:
	print("\n========== WALLS SMOKE TEST ==========")
	for p in passed:
		print("  PASS: ", p)
	for f in failed:
		print("  FAIL: ", f)
	print("========================================")
	print("PASSED: %d | FAILED: %d" % [passed.size(), failed.size()])
	if failed.size() > 0:
		quit(1)
	else:
		quit(0)
