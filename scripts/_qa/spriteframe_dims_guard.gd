extends SceneTree

## ponytail: guards against the "frame atlas mismatch" bug where the
## SpriteFrames region size doesn't match the actual atlas file size.
## Run with:
##   godot --headless -s scripts/_qa/spriteframe_dims_guard.gd --quit-after 10

const CHECKS := [
	# [spriteframes_path, atlas_path, expected_cell_w, expected_cell_h]
	["res://resources/personaje_spriteframes.tres", "res://assets/textures/personaje_idle.png", 344, 280],
	["res://resources/personaje_spriteframes.tres", "res://assets/textures/personaje_walk.png", 344, 280],
	["res://resources/personaje_spriteframes.tres", "res://assets/textures/personaje_interact.png", 344, 280],
	["res://resources/personaje_spriteframes.tres", "res://assets/textures/personaje_hurt.png", 344, 280],
	["res://resources/crow_spriteframes.tres", "res://assets/textures/crow_idle.png", 320, 320],
	["res://resources/crow_spriteframes.tres", "res://assets/textures/crow_walk.png", 320, 320],
	["res://resources/crow_spriteframes.tres", "res://assets/textures/crow_attack.png", 320, 320],
	["res://resources/crow_spriteframes.tres", "res://assets/textures/crow_hurt.png", 320, 320],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	for c in CHECKS:
		var sf_path: String = c[0]
		var atlas_path: String = c[1]
		var expected_w: int = c[2]
		var expected_h: int = c[3]

		var atlas_img := Image.load_from_file(atlas_path)
		if atlas_img == null:
			failed += 1
			print("  FAIL: cannot load %s" % atlas_path)
			continue
		var atlas_h: int = atlas_img.get_height()
		var atlas_w: int = atlas_img.get_width()

		var sf: Resource = load(sf_path)
		if sf == null:
			failed += 1
			print("  FAIL: cannot load %s" % sf_path)
			continue

		# Inspect the first non-empty frame region via the first animation that has frames.
		var anim_names: PackedStringArray = sf.get_animation_names()
		if anim_names.size() == 0:
			failed += 1
			print("  FAIL: %s has no animations" % sf_path)
			continue
		var first_anim: String = ""
		for name in anim_names:
			if sf.get_frame_count(name) > 0:
				first_anim = name
				break
		if first_anim == "":
			failed += 1
			print("  FAIL: %s has no animation with frames" % sf_path)
			continue
		var frames_count: int = sf.get_frame_count(first_anim)
		if frames_count == 0:
			failed += 1
			print("  FAIL: %s animation %s has no frames" % [sf_path, first_anim])
			continue
		var frame_tex: Texture2D = sf.get_frame_texture(first_anim, 0)
		if frame_tex == null:
			failed += 1
			print("  FAIL: %s frame[0] is null" % first_anim)
			continue
		var region: Rect2 = frame_tex.region

		# Check the frame region size matches the expected cell size.
		if region.size == Vector2(expected_w, expected_h):
			passed += 1
		else:
			failed += 1
			print("  FRAME SIZE MISMATCH %s[%s]: expected %dx%d, got %s" % [
				sf_path.get_file(), first_anim, expected_w, expected_h, region.size
			])

		# Check that the frame region fits inside the actual atlas.
		if region.position.x + region.size.x <= atlas_w and region.position.y + region.size.y <= atlas_h:
			passed += 1
		else:
			failed += 1
			print("  FRAME OUT OF BOUNDS %s[%s]: region=%s, atlas=%dx%d" % [
				sf_path.get_file(), first_anim, region, atlas_w, atlas_h
			])

	print("\n========== SPRITEFRAME DIMS GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)
