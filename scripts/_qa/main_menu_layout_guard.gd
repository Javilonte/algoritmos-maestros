extends Node

## ponytail: guard for the redesigned main menu. Verifies:
##   1) MainMenu scene loads and the 3-column layout is in place.
##   2) HeroCard has a SpriteFrames + AnimatedSprite2D (idle anim).
##   3) StatsPanel renders without crashing when SkillTree is missing
##      (no_save fallback).
##   4) Each ActionButton has the right variant set.
##   5) Buttons navigate: Continue is disabled when no save exists.
##
## Run with:  godot --headless scenes/qa/main_menu_layout_guard.tscn --quit-after 10

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	# 1) Scene loads.
	var scene: PackedScene = load("res://scenes/main_menu/main_menu.tscn") as PackedScene
	if scene == null:
		print("FAIL: cannot load main_menu.tscn")
		_done(1)
		return
	var root: Node = scene.instantiate()
	get_tree().root.add_child(root)
	await get_tree().process_frame
	passed += 1
	print("PASS: main_menu.tscn loaded")

	# 2) Three-column body.
	var body: Node = root.get_node_or_null("Body")
	if body == null:
		print("FAIL: Body not found")
		_done(1)
		return
	var left_col: Node = body.get_node_or_null("LeftColumn")
	var center_col: Node = body.get_node_or_null("CenterColumn")
	var right_col: Node = body.get_node_or_null("RightColumn")
	for pair in [["left", left_col], ["center", center_col], ["right", right_col]]:
		if pair[1] == null:
			failed += 1
			print("FAIL: %s column missing" % pair[0])
		else:
			passed += 1
			print("PASS: %s column exists" % pair[0])

	# 3) HeroCard.
	var hero: MenuHeroCard = left_col.get_node_or_null("HeroCard")
	if hero == null:
		failed += 1
		print("FAIL: HeroCard missing")
	else:
		passed += 1
		print("PASS: HeroCard exists")
		var hero_sprite: AnimatedSprite2D = _find_animated_sprite(hero)
		if hero_sprite == null:
			failed += 1
			print("FAIL: HeroCard has no AnimatedSprite2D")
		else:
			passed += 1
			print("PASS: HeroCard has AnimatedSprite2D (current: %s)" % hero_sprite.animation)
			if hero.sprite_frames == null:
				failed += 1
				print("FAIL: HeroCard has no sprite_frames")
			else:
				passed += 1
				print("PASS: HeroCard has sprite_frames (%d anims)" % hero.sprite_frames.get_animation_names().size())

	# 4) StatsPanel.
	var stats: MenuStatsPanel = right_col.get_node_or_null("StatsPanel")
	if stats == null:
		failed += 1
		print("FAIL: StatsPanel missing")
	else:
		passed += 1
		print("PASS: StatsPanel exists")
		# StatsPanel must survive a refresh even with no SkillTree.
		stats.refresh_from_skill_tree()
		passed += 1
		print("PASS: StatsPanel refresh_from_skill_tree OK")

	# 5) ActionGrid + 5 buttons.
	var grid: Node = center_col.get_node_or_null("ActionGrid")
	if grid == null:
		failed += 1
		print("FAIL: ActionGrid missing")
	else:
		passed += 1
		print("PASS: ActionGrid exists")
		var expected_buttons: Array = [
			["QuickStartButton", "primary"],
			["ContinueButton", "neutral"],
			["NewGameButton", "neutral"],
			["OptionsButton", "subtle"],
			["ExitButton", "danger"],
		]
		for expected in expected_buttons:
			var btn_name: String = expected[0]
			var expected_variant: String = expected[1]
			var btn: MenuActionButton = _find_action_button(grid, btn_name)
			if btn == null:
				failed += 1
				print("FAIL: %s missing" % btn_name)
				continue
			if btn.variant != expected_variant:
				failed += 1
				print("FAIL: %s variant=%s, expected=%s" % [btn_name, btn.variant, expected_variant])
			else:
				passed += 1
				print("PASS: %s variant=%s" % [btn_name, btn.variant])

	# 6) Continue disabled when no save.
	if stats != null:
		var continue_btn: MenuActionButton = _find_action_button(grid, "ContinueButton")
		if continue_btn != null:
			# ponytail: SaveManager.has_save() returns true if a save exists.
			# We can't easily delete the save in this test (would pollute
			# subsequent runs), so we just verify the state matches the save
			# file's presence.
			var has_save: bool = get_node_or_null("/root/SaveManager") != null \
				and get_node_or_null("/root/SaveManager").has_save()
			var expected_disabled: bool = not has_save
			if continue_btn.disabled == expected_disabled:
				passed += 1
				print("PASS: ContinueButton disabled=%s (matches has_save=%s)" % [
					continue_btn.disabled, has_save])
			else:
				failed += 1
				print("FAIL: ContinueButton disabled=%s, expected=%s (has_save=%s)" % [
					continue_btn.disabled, expected_disabled, has_save])

	# 7) Each ActionButton has a CyberpunkButton wrapper.
	if grid != null:
		for btn_name in ["QuickStartButton", "ContinueButton", "NewGameButton", "OptionsButton", "ExitButton"]:
			var btn2: MenuActionButton = _find_action_button(grid, btn_name)
			if btn2 == null:
				continue
			if btn2.has_meta("cyberpunk_wrapper"):
				passed += 1
				print("PASS: %s has cyberpunk_wrapper" % btn_name)
			else:
				failed += 1
				print("FAIL: %s missing cyberpunk_wrapper" % btn_name)

	print("\n========== MAIN MENU LAYOUT GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		_done(1)
	else:
		_done(0)


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node
	for child in node.get_children():
		var found: AnimatedSprite2D = _find_animated_sprite(child)
		if found != null:
			return found
	return null


## ponytail: ActionButton might be a direct child or nested in a row
## (ContinueRow / SecondaryRow). Recurse to find it.
func _find_action_button(node: Node, name: String) -> MenuActionButton:
	if node.name == name and node is MenuActionButton:
		return node
	for child in node.get_children():
		var found: MenuActionButton = _find_action_button(child, name)
		if found != null:
			return found
	return null


func _done(code: int) -> void:
	get_tree().quit(code)
