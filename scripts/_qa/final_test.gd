extends Node

# End-to-end visual + movement test for the cyberpunk iso demo.
# Captures 4 frames: idle, then 3 frames during simulated movement
# to verify animation switching, camera follow, and squash/stretch.

const DEMO_SCENE := "res://scenes/iso/iso_demo.tscn"


func _ready() -> void:
	var ps: PackedScene = load(DEMO_SCENE)
	var demo: Node = ps.instantiate()
	add_child(demo)

	# Wait for autoloads + scene tree to settle.
	for i in range(6):
		await get_tree().process_frame

	var img: Image = get_viewport().get_texture().get_image()
	if img:
		img.save_png("/tmp/final_01_idle.png")
		print("Saved /tmp/final_01_idle.png")

	# Find the player and simulate movement.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		print("FAIL: no player in group")
		get_tree().quit(1); return
	var player: CharacterBody2D = players[0]

	# Simulate 10 frames of "right" movement by setting velocity directly.
	for i in range(10):
		player.velocity = Vector2(150.0, 0.0)
		player.move_and_slide()
		await get_tree().physics_frame

	img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("/tmp/final_02_walking_right.png")
		print("Saved /tmp/final_02_walking_right.png  player_pos=%s" % player.global_position)

	# Simulate 10 frames of "down" movement.
	for i in range(10):
		player.velocity = Vector2(0.0, 150.0)
		player.move_and_slide()
		await get_tree().physics_frame

	img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("/tmp/final_03_walking_down.png")
		print("Saved /tmp/final_03_walking_down.png  player_pos=%s" % player.global_position)

	# Stop and settle.
	for i in range(20):
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		await get_tree().physics_frame

	img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("/tmp/final_04_stopped.png")
		print("Saved /tmp/final_04_stopped.png  player_pos=%s" % player.global_position)

	# Verify camera follows player.
	var cam := get_viewport().get_camera_2d()
	if cam:
		print("Camera pos: %s  Player pos: %s" % [cam.global_position, player.global_position])

	get_tree().quit(0)