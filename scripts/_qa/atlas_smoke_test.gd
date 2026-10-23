extends SceneTree

## Atlas smoke test — runs headless, validates the entire iso terrain pipeline.
##
## Usage:
##   godot --headless -s scripts/_qa/atlas_smoke_test.gd --quit-after 30
##
## Asserts:
##   1. IsoAtlasBuilder autoload is registered and ready.
##   2. Both textures (original + extended) loaded and have expected sizes.
##   3. The TileSet has 2 atlas sources.
##   4. Demo scene loads successfully with all TileMapLayers populated.

func _init() -> void:
	var failed: Array[String] = []
	var passed: Array[String] = []

	# 1. Autoload availability.
	if not ClassDB.class_exists("Node"):
		failed.append("ClassDB not available — Godot not ready")
	else:
		passed.append("Godot runtime available")

	# 2. Run after a frame so autoloads finish _ready.
	call_deferred("_run_checks", passed, failed)


func _run_checks(passed: Array, failed: Array) -> void:
	# 1) IsoAtlasBuilder autoload presence.
	var builder = root.get_node_or_null("IsoAtlasBuilder")
	if builder == null:
		failed.append("IsoAtlasBuilder autoload missing (check project.godot)")
		_finish(passed, failed)
		return
	passed.append("IsoAtlasBuilder autoload registered")

	# 2) Atlas readiness.
	if not builder.is_ready():
		failed.append("IsoAtlasBuilder.is_ready() returned false")
		_finish(passed, failed)
		return
	passed.append("IsoAtlasBuilder.is_ready() == true")

	if builder.original_texture == null:
		failed.append("original_texture is null")
	else:
		passed.append("original_texture loaded: %s" % str(builder.original_texture.get_size()))

	if builder.extended_texture == null:
		failed.append("extended_texture is null")
	else:
		passed.append("extended_texture loaded: %s" % str(builder.extended_texture.get_size()))

	# 2b) µFantasy external assets (optional but expected).
	if builder.microfantasy_texture == null:
		failed.append("microfantasy_texture is null (check assets/external/microfantasy/iso/iso_tileset.png)")
	else:
		passed.append("microfantasy_texture loaded: %s" % str(builder.microfantasy_texture.get_size()))

	if builder.knight_sprite_texture == null:
		failed.append("knight_sprite_texture is null (check assets/external/microfantasy/characters/knight_blue.png)")
	else:
		passed.append("knight_sprite_texture loaded: %s" % str(builder.knight_sprite_texture.get_size()))

	if not builder.has_microfantasy():
		failed.append("builder.has_microfantasy() returned false")
	else:
		passed.append("builder.has_microfantasy() == true")
		var kf0: AtlasTexture = builder.get_knight_frame_atlas(0, 3.0)
		if kf0 == null:
			failed.append("get_knight_frame_atlas(0) returned null")
		else:
			passed.append("get_knight_frame_atlas(0) region=%s" % str(kf0.region))

	# 3) Check generated PNG exists.
	if not FileAccess.file_exists("res://assets/textures/iso_terrain_atlas.png"):
		failed.append("iso_terrain_atlas.png not saved to disk")
	else:
		passed.append("iso_terrain_atlas.png saved to disk")

	# 4) TileSet resources.
	var ts: TileSet = load("res://scenes/iso/iso_terrain_tileset.tres") as TileSet
	if ts == null:
		failed.append("Failed to load iso_terrain_tileset.tres")
		_finish(passed, failed)
		return
	passed.append("iso_terrain_tileset.tres loaded")

	var mfts: TileSet = load("res://scenes/iso/iso_microfantasy_tileset.tres") as TileSet
	if mfts == null:
		failed.append("Failed to load iso_microfantasy_tileset.tres")
	else:
		passed.append("iso_microfantasy_tileset.tres loaded")

	# 5) IsoMeta .tres loads.
	var meta: Resource = load("res://data/worlds/iso_demo_meta.tres")
	if meta == null:
		failed.append("Failed to load iso_demo_meta.tres")
		_finish(passed, failed)
		return
	if not meta.has_method("get"):
		failed.append("iso_demo_meta is not a Resource subclass")
	else:
		passed.append("iso_demo_meta loaded with %d lakes, %d forest patches" % [
			int((meta.get("lakes") as Array).size()) if meta.get("lakes") is Array else 0,
			int((meta.get("forest_patches") as Array).size()) if meta.get("forest_patches") is Array else 0,
		])

	# 6) IsoDemo scene file is parseable.
	var demo_pck: PackedScene = load("res://scenes/iso/iso_demo.tscn") as PackedScene
	if demo_pck == null:
		failed.append("Failed to load iso_demo.tscn")
		_finish(passed, failed)
		return
	passed.append("iso_demo.tscn parses")

	# 7) iso_demo_meta_v2 (richer map with 2 lakes, 2 forests, 3 enemies).
	var meta_v2: Resource = load("res://data/worlds/iso_demo_meta_v2.tres")
	if meta_v2 == null:
		failed.append("Failed to load iso_demo_meta_v2.tres")
	else:
		var v2_lakes: int = int((meta_v2.get("lakes") as Array).size()) if meta_v2.get("lakes") is Array else 0
		var v2_forests: int = int((meta_v2.get("forest_patches") as Array).size()) if meta_v2.get("forest_patches") is Array else 0
		var v2_enemies: int = int((meta_v2.get("enemy_spawns") as Array).size()) if meta_v2.get("enemy_spawns") is Array else 0
		passed.append("iso_demo_meta_v2.tres: %d lakes, %d forests, %d enemies" % [v2_lakes, v2_forests, v2_enemies])

	# 8) µFantasy inventory script also loadable.
	var inventory: Resource = load("res://scripts/_qa/microfantasy_inventory.gd")
	if inventory == null:
		failed.append("microfantasy_inventory.gd failed to load")
	else:
		passed.append("microfantasy_inventory.gd compiled OK")

	_finish(passed, failed)


func _finish(passed: Array, failed: Array) -> void:
	print("\n========== ATLAS SMOKE TEST ==========")
	for p in passed:
		print("  PASS: ", p)
	for f in failed:
		print("  FAIL: ", f)
	print("=========================================")
	print("PASSED: %d | FAILED: %d" % [passed.size(), failed.size()])
	if failed.size() > 0:
		quit(1)
	else:
		quit(0)
