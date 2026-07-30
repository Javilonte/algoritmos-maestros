extends SceneTree

## ponytail: end-to-end test. Loads iso_demo.tscn, simulates the player
## walking east for 3 seconds, and asserts that the crow at (2, 0)
## triggers a battle_requested event.
##
## Run with:
##   godot --headless -s scripts/_qa/crow_collision_e2e.gd --quit-after 30

const SPAWN := Vector2i(2, 0)
const PHYSICS_TICK := 1.0 / 60.0
const SIM_SECONDS := 4.0


func _init() -> void:
	# Hook the event bus signal BEFORE loading the scene so we catch the
	# emission from the moment the demo starts.
	EventBus.battle_requested.connect(_on_battle_requested)
	# Defer scene load so the autoloads are ready.
	call_deferred("_setup")


func _setup() -> void:
	# Load the demo scene.
	var demo: PackedScene = load("res://scenes/iso/iso_demo.tscn") as PackedScene
	if demo == null:
		print("FAIL: cannot load iso_demo.tscn")
		quit(1)
		return
	var demo_root: Node = demo.instantiate()
	get_root().add_child(demo_root)
	await process_frame
	await process_frame

	# Find the player and the crow at SPAWN.
	var player: Node = demo_root.get_node_or_null("IsoPlayer")
	if player == null:
		print("FAIL: IsoPlayer not found")
		quit(1)
		return

	var enemies: Node = demo_root.get_node_or_null("Enemies")
	if enemies == null:
		print("FAIL: Enemies container not found")
		quit(1)
		return

	# Find the crow whose tile_position matches SPAWN.
	var target_crow: Node = null
	for child in enemies.get_children():
		if child.tile_position == SPAWN:
			target_crow = child
			break
	if target_crow == null:
		print("FAIL: no crow at SPAWN %s" % SPAWN)
		quit(1)
		return
	print("Spawned crow at %s, screen pos %s" % [SPAWN, target_crow.position])

	# Verify the crow's hit area radius.
	var hit_shape: CollisionShape2D = target_crow.get_node("HitArea/HitShape")
	if hit_shape.shape.radius != 80.0:
		print("FAIL: HitShape radius is %s, expected 80" % hit_shape.shape.radius)
		quit(1)
		return

	# Allow the player + crow to settle.
	await create_timer(0.2).timeout

	# Simulate the player walking east (input (1, 0) per frame).
	# The CrowSpawn at (2,0) is at screen (50, 28) relative to IsoDemo.
	# Player walking E (input (1, 0)) moves at (0.873, 0.489) * 200 = (175, 98) per sec.
	# After 0.143 sec the player reaches x=25 (passing through the spawn point).
	# We'll override the player's input by directly setting velocity.
	var ticks: int = int(SIM_SECONDS / PHYSICS_TICK)
	var initial_pos: Vector2 = player.global_position
	print("Player initial pos: %s" % initial_pos)
	print("Crow pos: %s" % target_crow.global_position)
	print("Initial distance: %.1f" % initial_pos.distance_to(target_crow.global_position))

	for tick in range(ticks):
		# Directly set velocity to simulate pressing right.
		player.velocity = Vector2(175.0, 98.0)
		player.move_and_slide()
		# The player moves; check if we've gotten close.
		if target_crow.global_position.distance_to(player.global_position) < 100.0:
			print("Near collision at tick %d (distance %.1f)" % [
				tick, target_crow.global_position.distance_to(player.global_position)
			])
		await create_timer(PHYSICS_TICK).timeout

	# Wait a bit for the collision event to propagate.
	await create_timer(0.2).timeout

	if _battle_emitted:
		print("PASS: battle_requested emitted — collision works")
		quit(0)
	else:
		print("FAIL: player walked for %ds but no battle_requested emitted" % SIM_SECONDS)
		print("Final player pos: %s" % player.global_position)
		print("Final crow pos: %s" % target_crow.global_position)
		quit(1)


var _battle_emitted: bool = false


func _on_battle_requested(data: Dictionary) -> void:
	_battle_emitted = true
	print("BATTLE REQUESTED: %s" % data.get("display_name", "?"))
