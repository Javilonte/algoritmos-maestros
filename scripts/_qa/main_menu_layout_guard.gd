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
	# ponytail: el viewport headless por defecto mide 64x64, y el menu se
	# armaba con el tamano minimo de sus tarjetas en vez del tamano real.
	# Las aserciones de layout tienen que medir sobre la resolucion del
	# juego.
	var win: Window = get_tree().root
	win.size = Vector2i(1152, 648)
	win.content_scale_size = Vector2i(1152, 648)
	await get_tree().process_frame
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

	# 8) The hero art stays INSIDE its card. ponytail: un Button... no, un
	# AnimatedSprite2D dentro de un CenterContainer nunca se movia y se
	# dibujaba medio fuera del marco. Esta es la asercion que faltaba.
	var hero_card_node: MenuHeroCard = left_col.get_node_or_null("HeroCard") as MenuHeroCard
	if hero_card_node == null:
		failed += 1
		print("FAIL: HeroCard missing")
	else:
		var sprite: AnimatedSprite2D = _find_animated_sprite(hero_card_node)
		var art: Control = _find_art_panel(hero_card_node)
		if sprite == null or art == null:
			failed += 1
			print("FAIL: hero card has no sprite/art panel")
		else:
			var drawn: Rect2 = SpriteInFrame.drawn_rect(sprite)
			var art_rect: Rect2 = art.get_global_rect()
			if art_rect.encloses(drawn):
				passed += 1
				print("PASS: hero art inside its card (drawn=%s art=%s)" % [drawn, art_rect])
			else:
				failed += 1
				print("FAIL: hero art OVERFLOWS its card: drawn=%s art=%s" % [drawn, art_rect])

	# 9) The hero card and the stats panel are the same width and both
	# fill the column. Antes eran 200 y 240 con alturas distintas: el
	# menu se leia descuadrado.
	var stats_panel_node: Control = right_col.get_node_or_null("StatsPanel") as Control
	if hero_card_node != null and stats_panel_node != null:
		if absf(hero_card_node.size.x - stats_panel_node.size.x) < 1.0:
			passed += 1
			print("PASS: hero card and stats panel share a width (%.0f)" % hero_card_node.size.x)
		else:
			failed += 1
			print("FAIL: column widths differ: hero=%.0f stats=%.0f" % [
				hero_card_node.size.x, stats_panel_node.size.x])
		if hero_card_node.size.y > 200.0 and absf(hero_card_node.size.y - stats_panel_node.size.y) < 1.0:
			passed += 1
			print("PASS: hero card and stats panel share a height (%.0f)" % hero_card_node.size.y)
		else:
			failed += 1
			print("FAIL: column heights differ: hero=%.0f stats=%.0f" % [
				hero_card_node.size.y, stats_panel_node.size.y])

	# 10) The menu background is opaque and dark. Con la paleta de
	# Diablo II el fondo era oliva y el codigo ambiente no se veia.
	var background: Panel = root.get_node_or_null("Background") as Panel
	if background == null:
		failed += 1
		print("FAIL: Background missing")
	else:
		var bg_style: StyleBoxFlat = background.get_theme_stylebox("panel") as StyleBoxFlat
		if bg_style != null and bg_style.bg_color.a >= 0.99 and bg_style.bg_color.get_luminance() < 0.2:
			passed += 1
			print("PASS: menu background is opaque and dark")
		else:
			failed += 1
			print("FAIL: menu background is not opaque/dark: %s" % (
				bg_style.bg_color if bg_style != null else "no stylebox"))

	# 11) No button label carries an emoji. Se renderizan con la fuente
	# del sistema, con metricas propias y fuera de la paleta.
	if grid != null:
		for btn_name in ["QuickStartButton", "ContinueButton", "NewGameButton", "OptionsButton", "ExitButton"]:
			var btn3: MenuActionButton = _find_action_button(grid, btn_name)
			if btn3 == null:
				continue
			var label_texts: Array = _all_label_texts(btn3)
			if label_texts.is_empty():
				failed += 1
				print("FAIL: %s has no label" % btn_name)
				continue
			var emoji_found: bool = false
			for t in label_texts:
				if _has_emoji(String(t)):
					emoji_found = true
			if emoji_found:
				failed += 1
				print("FAIL: %s label has an emoji: %s" % [btn_name, label_texts])
			else:
				passed += 1
				print("PASS: %s label is plain text %s" % [btn_name, label_texts])

	# 12) The button labels sit INSIDE the button. ponytail: un Button no
	# es un Container, asi que su VBox se quedaba en (0,0) con el texto
	# pegado al borde y la primera letra bajo el marco.
	if grid != null:
		for btn_name in ["QuickStartButton", "ContinueButton", "NewGameButton", "OptionsButton", "ExitButton"]:
			var btn4: MenuActionButton = _find_action_button(grid, btn_name)
			if btn4 == null:
				continue
			var label_node: Label = _find_label(btn4)
			if label_node == null:
				failed += 1
				print("FAIL: %s has no label" % btn_name)
				continue
			if btn4.get_global_rect().encloses(label_node.get_global_rect()):
				passed += 1
				print("PASS: %s label is inside the button" % btn_name)
			else:
				failed += 1
				print("FAIL: %s label escapes the button: button=%s label=%s" % [
					btn_name, btn4.get_global_rect(), label_node.get_global_rect()])

	# 13) The XP bar shows the XP, not the widget's percentage.
	var xp_bar: HPBar = _find_hp_bar(stats_panel_node)
	if xp_bar == null:
		failed += 1
		print("FAIL: stats panel has no XP bar")
	else:
		if xp_bar.show_percentage:
			failed += 1
			print("FAIL: XP bar still shows the widget percentage")
		else:
			passed += 1
			print("PASS: XP bar percentage label off")

	# 14) Every skill slot is visible. El punto bloqueado era oscuro
	# sobre fondo oscuro: habia catorce ranuras y no se veia ninguna.
	var dots: int = _count_dots(stats_panel_node)
	if dots == 14:
		passed += 1
		print("PASS: the stats panel draws a dot per skill slot (%d)" % dots)
	else:
		failed += 1
		print("FAIL: the stats panel draws %d skill dots, expected 14" % dots)

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


## El area de arte es el Panel que TIENE el sprite de hijo.
func _find_art_panel(node: Node) -> Control:
	for child in node.get_children():
		if child is Panel and _find_animated_sprite(child) != null:
			return child
		var found: Control = _find_art_panel(child)
		if found != null:
			return found
	return null


func _find_hp_bar(node: Node) -> HPBar:
	if node is HPBar:
		return node
	for child in node.get_children():
		var found: HPBar = _find_hp_bar(child)
		if found != null:
			return found
	return null


func _find_label(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var found: Label = _find_label(child)
		if found != null:
			return found
	return null


## Todos los textos de un boton (el principal y el subtitulo).
func _all_label_texts(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_all_label_texts(child))
	return out


## Cuenta los puntos de habilidad: Panels cuadrados de 12 px dentro del
## panel de stats.
func _count_dots(node: Node) -> int:
	var count: int = 0
	if node is Panel:
		var p: Panel = node
		if p.custom_minimum_size == Vector2(12, 12):
			count += 1
	for child in node.get_children():
		count += _count_dots(child)
	return count


## Emoji y simbolos pictograficos viven por encima de U+2500.
func _has_emoji(text: String) -> bool:
	for i in text.length():
		if text.unicode_at(i) >= 0x2500:
			return true
	return false


func _done(code: int) -> void:
	get_tree().quit(code)
