extends Node

## ponytail: guard de las otras dos pantallas del combate — la terminal de
## codigo y la pantalla de derrota. Lo que vigila:
##   1) El CodeEdit tiene fondo PROPIO y oscuro. El tema global del
##      juego (d2_theme.tres) nunca setea `CodeEdit/colors/background_color`,
##      asi que el editor heredaba el gris claro por defecto de Godot y
##      el codigo se leia como texto oscuro sobre un rectangulo blanco.
##   2) Los botones de la terminal llevan estilo de la paleta, no el
##      boton gris del sistema.
##   3) La consola y el codigo se leen en la misma familia de color.
##   4) La pantalla de derrota tiene marco y usa la paleta compartida:
##      Reintentar es la accion del jugador (cyan) y Huir comparte el
##      amber del boton RUN de la pantalla de combate.
##
## Run with:  godot --headless scenes/qa/combat_ui_guard.tscn --quit-after 250

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	# --- the battle terminal -------------------------------------------------
	var terminal_scene: PackedScene = load("res://scenes/battle/battle_terminal.tscn") as PackedScene
	if terminal_scene == null:
		print("FAIL: cannot load battle_terminal.tscn")
		_done(1)
		return
	var terminal: Node = terminal_scene.instantiate()
	get_tree().root.add_child(terminal)
	await get_tree().process_frame
	await get_tree().process_frame

	var editor: CodeEdit = terminal.get_node_or_null("Panel/CodeEdit")
	if editor == null:
		failed += 1
		print("FAIL: terminal CodeEdit not found")
	else:
		var bg: Color = editor.get_theme_color("background_color")
		# ponytail: el fondo tiene que ser CLARO en el sentido de "no
		# beige": un color casi negro con un tinte. El gris claro por
		# defecto de Godot es (0.7, 0.7, 0.7).
		if bg.get_luminance() < 0.2:
			passed += 1
			print("PASS: terminal editor background is dark (%.3f)" % bg.get_luminance())
		else:
			failed += 1
			print("FAIL: terminal editor background is light (%.3f)" % bg.get_luminance())

		var font: Color = editor.get_theme_color("font_color")
		if font.get_luminance() > 0.5:
			passed += 1
			print("PASS: terminal editor text is light (%.3f)" % font.get_luminance())
		else:
			failed += 1
			print("FAIL: terminal editor text is dark (%.3f)" % font.get_luminance())

		var caret: Color = editor.get_theme_color("caret_color")
		if caret.get_luminance() > 0.4:
			passed += 1
			print("PASS: terminal caret is visible")
		else:
			failed += 1
			print("FAIL: terminal caret is invisible (%s)" % caret)

	for btn_name in ["SubmitButton", "BackButton"]:
		var btn: Button = terminal.get_node_or_null("Panel/" + btn_name)
		if btn == null:
			failed += 1
			print("FAIL: terminal %s not found" % btn_name)
			continue
		var normal: StyleBox = btn.get_theme_stylebox("normal")
		if normal is StyleBoxFlat and (normal as StyleBoxFlat).border_color.get_luminance() > 0.15:
			passed += 1
			print("PASS: terminal %s has a palette border" % btn_name)
		else:
			failed += 1
			print("FAIL: terminal %s still uses the default button" % btn_name)

	# --- the game over screen ------------------------------------------------
	var go_scene: PackedScene = load("res://scenes/ui/game_over.tscn") as PackedScene
	if go_scene == null:
		print("FAIL: cannot load game_over.tscn")
		_done(1)
		return
	var go: Node = go_scene.instantiate()
	get_tree().root.add_child(go)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: PanelContainer = go.get_node_or_null("CenterContainer/Panel")
	if panel == null:
		failed += 1
		print("FAIL: game over has no frame panel")
	else:
		passed += 1
		print("PASS: game over has a frame panel")

	var title: Label = go.get_node_or_null("CenterContainer/Panel/VBox/Title")
	if title == null:
		failed += 1
		print("FAIL: game over title not found")
	else:
		var title_color: Color = title.get_theme_color("font_color")
		if title_color.get_luminance() > 0.3 and title_color.r > title_color.b:
			passed += 1
			print("PASS: game over title is the danger colour")
		else:
			failed += 1
			print("FAIL: game over title colour is off-palette: %s" % title_color)

	# Reintentar is the player's action: cyan. Huir is the same action as
	# RUN on the battle screen: amber. Both must be on the palette.
	var expected := {"RetryButton": CyberStyleBox.CYAN, "RunButton": CyberStyleBox.AMBER}
	for btn_name in expected.keys():
		var btn: Button = go.get_node_or_null("CenterContainer/Panel/VBox/ButtonRow/" + btn_name)
		if btn == null:
			failed += 1
			print("FAIL: game over %s not found" % btn_name)
			continue
		var normal: StyleBox = btn.get_theme_stylebox("normal")
		if normal is StyleBoxFlat:
			var border: Color = (normal as StyleBoxFlat).border_color
			var want: Color = expected[btn_name]
			if border.is_equal_approx(want.darkened(0.25)):
				passed += 1
				print("PASS: game over %s uses the shared palette" % btn_name)
			else:
				failed += 1
				print("FAIL: game over %s border %s, expected %s" % [btn_name, border, want.darkened(0.25)])
		else:
			failed += 1
			print("FAIL: game over %s has no flat stylebox" % btn_name)

	print("\n========== COMBAT UI GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		_done(1)
	else:
		_done(0)


func _done(code: int) -> void:
	get_tree().quit(code)
