extends Node

## ponytail: guard de la pantalla de combate. Lo que vigila:
##   1) La escena carga y se puede medir (visible, 1152x648).
##   2) El arte de cada retrato cabe DENTRO de su area de arte. Este es
##      el invariante que nadie comprobaba: el sprite es un Node2D, los
##      contenedores no lo mueven, y con `centered = true` se dibujaba
##      desde -size/2. Medido, caia en y = -8.4, por encima de la pantalla.
##   3) El area de arte esta dentro de la carta.
##   4) La barra de HP ocupa el ancho completo de la carta.
##   5) El HP se lee como "cur/max", no como el "100%" del widget.
##   6) El fondo de la pantalla de combate es opaco.
##   7) El contador de turno vive dentro de su chip, no suelto en una
##      esquina de la pantalla.
##   8) Los botones no llevan emoji: se renderizan con la fuente del
##      sistema y rompen la paleta.
##
## Run with:  godot --headless scenes/qa/battle_layout_guard.tscn --quit-after 250

const REFERENCE_SIZE := Vector2i(1152, 648)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	var scene: PackedScene = load("res://scenes/battle/battle.tscn") as PackedScene
	if scene == null:
		print("FAIL: cannot load battle.tscn")
		_done(1)
		return

	var root: Node = scene.instantiate()
	get_tree().root.add_child(root)
	# ponytail: los contenedores de Godot no ordenan hijos si el arbol
	# esta invisible, asi que hay que medir con la pantalla visible.
	root.visible = true
	var win: Window = get_tree().root
	win.size = REFERENCE_SIZE
	win.content_scale_size = REFERENCE_SIZE
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) La arena existe.
	var arena: Node = root.get_node_or_null("BattleArena")
	if arena == null:
		print("FAIL: BattleArena not found")
		_done(1)
		return
	passed += 1
	print("PASS: BattleArena found")

	# 2) El arte cabe dentro del area de arte.
	for side in ["enemy", "player"]:
		var portrait: Node = root.get_node_or_null("BattleArena/PortraitsRow/%sPortrait" % side.capitalize())
		if portrait == null:
			failed += 1
			print("FAIL: %s portrait not found" % side)
			continue
		var sprite: AnimatedSprite2D = _find_sprite(portrait)
		var art: Control = _find_art_panel(portrait)
		if sprite == null or art == null:
			failed += 1
			print("FAIL: %s portrait has no sprite/art panel" % side)
			continue
		var cell: Vector2 = _frame_size(sprite)
		if cell.x <= 0.0 or cell.y <= 0.0:
			failed += 1
			print("FAIL: %s sprite has no measurable frame" % side)
			continue
		var drawn: Vector2 = cell * sprite.scale
		var drawn_rect := Rect2(sprite.global_position - drawn * 0.5, drawn)
		var art_rect: Rect2 = art.get_global_rect()
		if art_rect.encloses(drawn_rect):
			passed += 1
			print("PASS: %s art inside its frame (art=%s art_rect=%s drawn=%s)" % [
				side, drawn_rect, art_rect, art_rect.encloses(drawn_rect)])
		else:
			failed += 1
			print("FAIL: %s art OVERFLOWS its frame: drawn=%s art_rect=%s" % [
				side, drawn_rect, art_rect])

		# 3) El area de arte esta dentro de la carta.
		var card_rect: Rect2 = portrait.get_global_rect()
		if card_rect.encloses(art_rect):
			passed += 1
			print("PASS: %s art area inside the card" % side)
		else:
			failed += 1
			print("FAIL: %s art area outside the card: card=%s art=%s" % [
				side, card_rect, art_rect])

		# 4) La barra de HP ocupa el ancho de la carta.
		var hp_bar: HPBar = _find_hp_bar(portrait)
		if hp_bar == null:
			failed += 1
			print("FAIL: %s portrait has no HPBar" % side)
		else:
			var bar_width: float = hp_bar.size.x
			var card_width: float = portrait.size.x
			if bar_width >= card_width - 40.0:
				passed += 1
				print("PASS: %s HP bar spans the card (bar=%.0f card=%.0f)" % [
					side, bar_width, card_width])
			else:
				failed += 1
				print("FAIL: %s HP bar too narrow: bar=%.0f card=%.0f" % [
					side, bar_width, card_width])

			# 5) El HP se lee como cur/max.
			if hp_bar.show_percentage:
				failed += 1
				print("FAIL: %s HP bar still shows the widget percentage" % side)
			else:
				passed += 1
				print("PASS: %s HP bar percentage label off" % side)

		var value_label: Label = _find_hp_value_label(portrait)
		if value_label == null:
			failed += 1
			print("FAIL: %s portrait has no cur/max label" % side)
		else:
			passed += 1
			print("PASS: %s HP readout '%s'" % [side, value_label.text])

	# 6) El fondo es opaco.
	var background: Panel = root.get_node_or_null("BattleArena/Background")
	if background == null:
		failed += 1
		print("FAIL: Background not found")
	else:
		var style: StyleBoxFlat = background.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null and style.bg_color.a >= 0.99:
			passed += 1
			print("PASS: battle backdrop is opaque (alpha=%.2f)" % style.bg_color.a)
		else:
			failed += 1
			print("FAIL: battle backdrop is translucent (alpha=%.2f)" % [
				(style.bg_color.a if style != null else -1.0)])

	# 7) El contador de turno vive dentro de su chip y alineado a la derecha.
	var chip: Control = root.get_node_or_null("BattleArena/StatusBar/TimerChip")
	var timer_label: Label = root.get_node_or_null("BattleArena/StatusBar/TimerChip/TimerBox/TimerRow/BattleTimer")
	if chip == null or timer_label == null:
		failed += 1
		print("FAIL: timer chip / timer label not found")
	else:
		if chip.get_global_rect().encloses(timer_label.get_global_rect()):
			passed += 1
			print("PASS: turn timer inside its chip")
		else:
			failed += 1
			print("FAIL: turn timer outside its chip: chip=%s timer=%s" % [
				chip.get_global_rect(), timer_label.get_global_rect()])
		# El chip va a la derecha de la banda de estado. Si el combo se
		# oculta, el HBox pierde su primer hijo y el chip se va al otro
		# borde: el contador vuelve a flotar en una esquina.
		var arena_rect: Rect2 = arena.get_global_rect()
		if chip.get_global_rect().position.x > arena_rect.position.x + arena_rect.size.x * 0.5:
			passed += 1
			print("PASS: turn timer chip is right-aligned")
		else:
			failed += 1
			print("FAIL: turn timer chip is not right-aligned: chip=%s" % chip.get_global_rect())

	# 8) Los botones no llevan emoji.
	for btn_name in ["AttackButton", "RunButton"]:
		var btn: Button = root.get_node_or_null("BattleArena/ActionMenu/" + btn_name)
		if btn == null:
			failed += 1
			print("FAIL: %s not found" % btn_name)
			continue
		if _has_emoji(btn.text):
			failed += 1
			print("FAIL: %s label has an emoji: '%s'" % [btn_name, btn.text])
		else:
			passed += 1
			print("PASS: %s label is plain text ('%s')" % [btn_name, btn.text])

	print("\n========== BATTLE LAYOUT GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		_done(1)
	else:
		_done(0)


## Emoji y simbolos pictograficos viven por encima de U+2500. Un boton
## con emoji se renderiza con la fuente del sistema, no con la del juego.
func _has_emoji(text: String) -> bool:
	for i in text.length():
		if text.unicode_at(i) >= 0x2500:
			return true
	return false


func _frame_size(sprite: AnimatedSprite2D) -> Vector2:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return Vector2.ZERO
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if tex == null:
		return Vector2.ZERO
	return tex.region.size if tex is AtlasTexture else tex.get_size()


func _find_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node
	for child in node.get_children():
		var found: AnimatedSprite2D = _find_sprite(child)
		if found != null:
			return found
	return null


## El area de arte es el Panel que TIENE el sprite de hijo.
func _find_art_panel(node: Node) -> Control:
	for child in node.get_children():
		if child is Panel and _find_sprite(child) != null:
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


## La etiqueta que muestra "cur/max" es la unica Label con "/" en el texto.
func _find_hp_value_label(node: Node) -> Label:
	if node is Label and (node as Label).text.find("/") >= 0:
		return node
	for child in node.get_children():
		var found: Label = _find_hp_value_label(child)
		if found != null:
			return found
	return null


func _done(code: int) -> void:
	get_tree().quit(code)
