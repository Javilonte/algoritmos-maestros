extends SceneTree

## ponytail: guard that project.godot has no 3D-only settings:
##   - physics_engine="Jolt Physics" (or any 3D physics engine)
##   - rendering_device/driver.windows="d3d12" (or any explicit driver)
##   - config/features containing "Forward Plus" (3D-focused renderer)
##
## Run with:  godot --headless -s scripts/_qa/project_godot_2d_guard.gd --quit-after 10

const PROJECT_FILE := "res://project.godot"
const FORBIDDEN_SUBSTRINGS: Array[String] = [
	"physics_engine",
	"rendering_device/driver",
	"Forward Plus",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	var f := FileAccess.open(PROJECT_FILE, FileAccess.READ)
	if f == null:
		print("FAIL: cannot open %s" % PROJECT_FILE)
		quit(1)
		return
	var content: String = f.get_as_text()
	f.close()

	for bad in FORBIDDEN_SUBSTRINGS:
		if bad in content:
			failed += 1
			print("FAIL: %s contains forbidden substring \"%s\"" % [PROJECT_FILE, bad])
		else:
			passed += 1
			print("PASS: %s has no \"%s\"" % [PROJECT_FILE, bad])

	# Verify config/features only has 2D-compatible entries.
	# Godot 4.6 with no 3D features accepts: "4.6" alone or with "GL Compatibility".
	var features_line: String = ""
	for line in content.split("\n"):
		if line.begins_with("config/features="):
			features_line = line
			break
	if features_line.is_empty():
		failed += 1
		print("FAIL: no config/features line found")
	else:
		if "Forward Plus" in features_line:
			failed += 1
			print("FAIL: config/features includes Forward Plus (3D renderer)")
		else:
			passed += 1
			print("PASS: config/features is 2D-compatible: %s" % features_line)

	print("\n========== PROJECT GODOT 2D GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)