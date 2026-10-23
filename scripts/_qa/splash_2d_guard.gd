extends SceneTree

## ponytail: guard that the splash screen is 100% 2D — no Camera3D,
## Node3D, DirectionalLight3D, OmniLight3D, SubViewport (for 3D),
## or any other 3D-specific node type.
##
## Run with:  godot --headless -s scripts/_qa/splash_2d_guard.gd --quit-after 10

const SPLASH_SCENE := "res://scenes/ui/splash.tscn"

# 3D node types that must NOT appear in the splash scene.
const FORBIDDEN_TYPES: Array[String] = [
	"Camera3D",
	"Node3D",
	"DirectionalLight3D",
	"OmniLight3D",
	"SpotLight3D",
	"MeshInstance3D",
	"Area3D",
	"CollisionShape3D",
	"RigidBody3D",
	"StaticBody3D",
	"GpuParticles3D",
	"WorldEnvironment3D",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	var scene: PackedScene = load(SPLASH_SCENE) as PackedScene
	if scene == null:
		print("FAIL: cannot load %s" % SPLASH_SCENE)
		quit(1)
		return
	var root: Node = scene.instantiate()
	# ponytail: extend SceneTree means get_tree() returns self. We add the
	# splash directly to the SceneTree root (which IS the Window).
	root.add_child(root)
	await process_frame

	# Walk the tree and verify every node is a 2D type.
	var found_3d: Array[String] = []
	_scan(root, found_3d)

	if found_3d.is_empty():
		passed += 1
		print("PASS: splash scene is 100%% 2D (no 3D node types)")
	else:
		failed += 1
		print("FAIL: splash scene contains 3D nodes: %s" % str(found_3d))

	# Bonus: verify no SubViewportContainer wraps a 3D scene.
	var subviewports := _find_nodes_of_type(root, "SubViewportContainer")
	if subviewports.is_empty():
		passed += 1
		print("PASS: no SubViewportContainer in splash (no nested 3D rendering)")
	else:
		failed += 1
		print("FAIL: SubViewportContainer found in splash: %d" % subviewports.size())

	# Verify the splash links to MAIN_MENU via signal/script.
	var splash_script: GDScript = root.get_script() as GDScript
	if splash_script != null:
		var src: String = splash_script.source_code
		if "main_menu.tscn" in src:
			passed += 1
			print("PASS: splash references main_menu.tscn")
		else:
			failed += 1
			print("FAIL: splash script doesn't reference main_menu.tscn")

	print("\n========== SPLASH 2D GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func _scan(node: Node, found: Array[String]) -> void:
	for bad in FORBIDDEN_TYPES:
		if node.is_class(bad):
			found.append("%s (%s)" % [bad, node.name])
	for child in node.get_children():
		_scan(child, found)


func _find_nodes_of_type(node: Node, type_name: String) -> Array[String]:
	var found: Array[String] = []
	_collect_type(node, type_name, found)
	return found


func _collect_type(node: Node, type_name: String, out: Array[String]) -> void:
	if node.is_class(type_name):
		out.append(node.name)
	for child in node.get_children():
		_collect_type(child, type_name, out)