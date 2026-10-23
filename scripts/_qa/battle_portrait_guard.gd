extends Node

## ponytail: guard that the new BattlePortrait UI is correctly wired.
## Verifies:
##   1) Battle scene loads and has the new portrait structure.
##   2) EnemyPortrait and PlayerPortrait are BattlePortrait nodes.
##   3) Each portrait has a SpriteFrames resource assigned and
##      a non-null AnimatedSprite2D child.
##   4) The HP bar exists inside each portrait.
##   5) The Battle node listens to EventBus.battle_requested.

const EXPECTED_PLAYER_ANIM := "idle"
const EXPECTED_CROW_ANIM := "idle"


func _ready() -> void:
	call_deferred("_run")


func _done(code: int) -> void:
	get_tree().quit(code)


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	# 1) Scene loads.
	var scene: PackedScene = load("res://scenes/battle/battle.tscn") as PackedScene
	if scene == null:
		print("FAIL: cannot load battle.tscn")
		_done(1)
		return
	var root: Node = scene.instantiate()
	get_tree().root.add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2) New layout: BattleArena > PortraitsRow > EnemyPortrait / PlayerPortrait.
	var portraits_row: Node = root.get_node_or_null("BattleArena/PortraitsRow")
	if portraits_row == null:
		print("FAIL: PortraitsRow not found")
		_done(1)
		return
	passed += 1
	print("PASS: PortraitsRow found")

	var enemy_portrait: Node = portraits_row.get_node_or_null("EnemyPortrait")
	var player_portrait: Node = portraits_row.get_node_or_null("PlayerPortrait")
	if enemy_portrait == null:
		print("FAIL: EnemyPortrait not found")
		_done(1)
		return
	passed += 1
	print("PASS: EnemyPortrait exists")

	if player_portrait == null:
		print("FAIL: PlayerPortrait not found")
		_done(1)
		return
	passed += 1
	print("PASS: PlayerPortrait exists")

	# 3) Each portrait has a SpriteFrames resource + AnimatedSprite2D.
	for pair in [["enemy", enemy_portrait], ["player", player_portrait]]:
		var side: String = pair[0]
		var portrait: Node = pair[1]

		var sprite_frames: SpriteFrames = portrait.sprite_frames
		if sprite_frames == null:
			failed += 1
			print("FAIL: %s portrait has no sprite_frames" % side)
			continue
		passed += 1
		print("PASS: %s portrait has sprite_frames (%d anims: %s)" % [
			side, sprite_frames.get_animation_names().size(),
			str(sprite_frames.get_animation_names())
		])

		# 4) AnimatedSprite2D inside the portrait.
		var sprite: AnimatedSprite2D = _find_animated_sprite(portrait)
		if sprite == null:
			failed += 1
			print("FAIL: %s portrait has no AnimatedSprite2D" % side)
			continue
		passed += 1
		print("PASS: %s portrait has AnimatedSprite2D (current anim: %s)" % [
			side, sprite.animation
		])

		# 5) HP bar inside the portrait.
		var hp_bar: HPBar = _find_hp_bar(portrait)
		if hp_bar == null:
			failed += 1
			print("FAIL: %s portrait has no HPBar" % side)
			continue
		passed += 1
		print("PASS: %s portrait has HPBar (side=%s)" % [side, hp_bar.side])

	# 6) VSDivider exists.
	var vs: Node = portraits_row.get_node_or_null("VSDivider")
	if vs == null:
		failed += 1
		print("FAIL: VSDivider not found")
	else:
		passed += 1
		print("PASS: VSDivider found")

	# 7) Old EnemySide/PlayerSide should NOT exist (replaced by PortraitsRow).
	var old_enemy_side: Node = root.get_node_or_null("BattleArena/EnemySide")
	if old_enemy_side != null:
		failed += 1
		print("FAIL: old EnemySide node still present (should be removed)")
	else:
		passed += 1
		print("PASS: old EnemySide removed")

	# 8) Battle listens to battle_requested.
	var battle: Node = root
	var has_signal: bool = false
	for conn in EventBus.battle_requested.get_connections():
		if conn["callable"].get_object() == battle:
			has_signal = true
			break
	if not has_signal:
		failed += 1
		print("FAIL: Battle is not connected to EventBus.battle_requested")
	else:
		passed += 1
		print("PASS: Battle connected to EventBus.battle_requested")

	print("\n========== BATTLE PORTRAIT GUARD ==========")
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


func _find_hp_bar(node: Node) -> HPBar:
	if node is HPBar:
		return node
	for child in node.get_children():
		var found: HPBar = _find_hp_bar(child)
		if found != null:
			return found
	return null
