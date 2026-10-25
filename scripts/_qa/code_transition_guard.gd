extends Node

## ponytail: guard for the loading screen (code_transition). Verifies:
##   1) The scene loads and is 100% 2D.
##   2) The log was reduced to 3 lines — the screen is a transition, not a
##      report. It used to be 6 lines inside a giant empty D2 panel.
##   3) The typewriter advances and the progress bar tracks it.
##   4) The panel is on the neon palette, not the D2 brown one.
##
## Run with:  godot --headless scenes/qa/code_transition_guard.tscn --quit-after 400

const SCENE_PATH := "res://scenes/ui/code_transition.tscn"
const EXPECTED_LINES: int = 3

const FORBIDDEN_TYPES: Array[String] = [
	"Camera3D",
	"Node3D",
	"DirectionalLight3D",
	"OmniLight3D",
	"SpotLight3D",
	"MeshInstance3D",
	"Sprite3D",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		print("FAIL: cannot load %s" % SCENE_PATH)
		_done(1)
		return

	var root: Node = scene.instantiate()
	# ponytail: the screen changes scene when it finishes; the guard needs
	# a live instance to assert against, so that hop is turned off.
	root.set("auto_advance", false)
	add_child(root)

	var win: Window = get_tree().root
	win.size = Vector2i(1152, 648)
	win.content_scale_size = Vector2i(1152, 648)
	await get_tree().process_frame
	await get_tree().process_frame
	passed += 1
	print("PASS: code_transition.tscn loaded")

	# 1) 2D only.
	var found_3d: Array[String] = []
	_scan(root, found_3d)
	if found_3d.is_empty():
		passed += 1
		print("PASS: loading screen is 100%% 2D")
	else:
		failed += 1
		print("FAIL: loading screen contains 3D nodes: %s" % str(found_3d))

	# 2) The log is short.
	var log_label: RichTextLabel = root.get_node_or_null("Panel/Padding/Column/Log")
	if log_label == null:
		failed += 1
		print("FAIL: Log label missing")
		_done(1)
		return

	var progress: ProgressBar = root.get_node_or_null("Panel/Padding/Column/Progress")
	var pct_label: Label = root.get_node_or_null("Panel/Padding/Column/HeaderRow/PctLabel")

	# ponytail: el typewriter real tarda ~3.3 s. El guard acelera el timer
	# para no depender de la velocidad de frames del headless.
	var type_timer: Timer = root.get_node_or_null("TypeTimer")
	if type_timer != null:
		type_timer.wait_time = 0.002

	# The typewriter has to advance: text grows and the bar follows.
	# ponytail: `text` queda vacio despues de un `parse_bbcode`; el texto
	# visible se lee con `get_parsed_text`.
	var first_text: String = log_label.get_parsed_text()
	await get_tree().process_frame
	await get_tree().process_frame
	if log_label.get_parsed_text().length() >= first_text.length() and progress != null and progress.value > 0.0:
		passed += 1
		print("PASS: typewriter advances (progress=%.0f%%)" % progress.value)
	else:
		failed += 1
		print("FAIL: typewriter did not advance (progress=%s)" % (
			progress.value if progress != null else "n/a"))

	# 3) Run the whole sequence and check the final state.
	var frames: int = 0
	var max_pct: float = 0.0
	while frames < 900:
		await get_tree().process_frame
		frames += 1
		if pct_label != null:
			# ponytail: el ProgressBar recorta su propio valor a 100, asi
			# que la etiqueta es la unica testigo de un desborde. Se lee de ahi.
			var digits: String = pct_label.text.replace("CARGA ", "").replace("%", "").strip_edges()
			if digits.is_valid_int():
				max_pct = maxf(max_pct, float(digits.to_int()))
		if log_label.get_parsed_text().split("\n").size() >= EXPECTED_LINES and progress != null and progress.value >= 99.9:
			break

	var lines: int = log_label.get_parsed_text().split("\n").size()
	if lines == EXPECTED_LINES:
		passed += 1
		print("PASS: the log is reduced to %d lines" % EXPECTED_LINES)
	else:
		failed += 1
		print("FAIL: the log has %d lines, expected %d" % [lines, EXPECTED_LINES])

	if progress != null and progress.value >= 99.9:
		passed += 1
		print("PASS: progress bar reaches 100%%")
	else:
		failed += 1
		print("FAIL: progress bar stalled at %s" % (
			progress.value if progress != null else "n/a"))

	# The percentage must never exceed 100: the bar clamps its own value,
	# so an overshoot only shows in the label.
	if pct_label != null and pct_label.text.contains("100"):
		passed += 1
		print("PASS: the percentage label reads 100%% (%s)" % pct_label.text)
	else:
		failed += 1
		print("FAIL: the percentage label does not read 100%% (%s)" % (
			pct_label.text if pct_label != null else "n/a"))

	# The label is the only witness of an overshoot, so sample it while it
	# runs instead of trusting the clamped bar value.
	if max_pct <= 100.0:
		passed += 1
		print("PASS: the progress never overshoots (max=%.0f%%)" % max_pct)
	else:
		failed += 1
		print("FAIL: the progress overshot: %.0f%%" % max_pct)

	# 4) The panel is neon, not the D2 bronze of the old loading screen.
	var panel: Panel = root.get_node_or_null("Panel")
	if panel == null:
		failed += 1
		print("FAIL: Panel missing")
	else:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			failed += 1
			print("FAIL: the panel has no flat stylebox")
		elif style.border_color.b > style.border_color.r and style.border_color.g > style.border_color.r:
			passed += 1
			print("PASS: the panel is on the neon palette (%s)" % style.border_color)
		else:
			failed += 1
			print("FAIL: the panel is not neon: %s" % style.border_color)

	print("\n========== CODE TRANSITION GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	_done(1 if failed > 0 else 0)


func _scan(node: Node, found: Array[String]) -> void:
	for bad in FORBIDDEN_TYPES:
		if node.is_class(bad):
			found.append("%s (%s)" % [bad, node.name])
	for child in node.get_children():
		_scan(child, found)


func _done(code: int) -> void:
	get_tree().quit(code)
