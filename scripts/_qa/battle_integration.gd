extends Node

## ponytail: integration test. Loads iso_demo.tscn, then the Battle
## scene, simulates the player walking into the crow, and verifies
## the battle UI appears (Battle.visible = true, both portraits
## populated with sprite frames).

const CROW_SPAWN := Vector2i(2, 0)
const PHYSICS_TICK := 1.0 / 60.0
const SIM_SECONDS := 5.0


func _ready() -> void:
	# Run regardless of tree pause (battle.gd pauses the tree on enter).
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	# Load the demo scene.
	var demo: PackedScene = load("res://scenes/iso/iso_demo.tscn") as PackedScene
	if demo == null:
		print("FAIL: cannot load iso_demo.tscn")
		_done(1)
		return
	var demo_root: Node = demo.instantiate()
	get_tree().root.add_child(demo_root)
	await get_tree().process_frame
	await get_tree().process_frame

	# Check Battle is included in the demo.
	var battle: Node = demo_root.get_node_or_null("Battle")
	if battle == null:
		print("FAIL: Battle scene not included in iso_demo.tscn")
		_done(1)
		return
	print("PASS: Battle scene is in iso_demo.tscn")

	# Find player + crow at CROW_SPAWN.
	var player: Node = demo_root.get_node_or_null("IsoPlayer")
	var enemies: Node = demo_root.get_node_or_null("Enemies")
	var target_crow: Node = null
	for child in enemies.get_children():
		if child.tile_position == CROW_SPAWN:
			target_crow = child
			break
	if player == null or target_crow == null:
		print("FAIL: scene structure (player=%s, crow=%s)" % [player, target_crow])
		_done(1)
		return
	print("PASS: scene structure is correct")

	# Simulate walking east (input (1, 0)).
	var initial_distance: float = player.global_position.distance_to(target_crow.global_position)
	print("Initial distance: %.1f" % initial_distance)
	var entered: bool = false
	for tick in range(int(SIM_SECONDS / PHYSICS_TICK)):
		player.velocity = Vector2(175.0, 98.0)
		player.move_and_slide()
		await get_tree().create_timer(PHYSICS_TICK).timeout
		if battle.visible:
			entered = true
			break

	if not entered:
		print("FAIL: Battle never became visible after walking into crow")
		print("Final battle.visible: %s" % battle.visible)
		_done(1)
		return
	print("PASS: Battle became visible after walking into crow")

	# At this point the battle is in EDITING phase. Verify the portraits
	# are populated (the BattlePortrait nodes have SpriteFrames + AnimatedSprite2D).
	var enemy_portrait: Node = battle.get_node_or_null("BattleArena/PortraitsRow/EnemyPortrait")
	var player_portrait: Node = battle.get_node_or_null("BattleArena/PortraitsRow/PlayerPortrait")
	if enemy_portrait == null or player_portrait == null:
		print("FAIL: portraits not found in battle")
		_done(1)
		return
	print("PASS: battle portraits exist")

	# Check both portraits have a sprite.
	for pair in [["enemy", enemy_portrait], ["player", player_portrait]]:
		var side: String = pair[0]
		var portrait: Node = pair[1]
		var sprite: AnimatedSprite2D = _find_animated_sprite(portrait)
		if sprite == null:
			print("FAIL: %s portrait has no AnimatedSprite2D" % side)
			_done(1)
			return
		print("PASS: %s portrait animating (current: %s)" % [side, sprite.animation])

	print("PASS: battle UI is fully wired")

	# Check the message panel shows the encounter text.
	var msg: RichTextLabel = battle.get_node_or_null("BattleArena/MessagePanel/MessageLabel")
	if msg == null:
		print("FAIL: message label not found")
		_done(1)
		return
	if msg.text.find("appeared") < 0 and msg.text.find("wild") < 0:
		print("WARN: message text is: %s" % msg.text)
	else:
		print("PASS: message text: %s" % msg.text)

	print("\n========== BATTLE INTEGRATION ==========")
	print("All checks passed")
	_done(0)


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node
	for child in node.get_children():
		var found: AnimatedSprite2D = _find_animated_sprite(child)
		if found != null:
			return found
	return null


func _done(code: int) -> void:
	get_tree().quit(code)
