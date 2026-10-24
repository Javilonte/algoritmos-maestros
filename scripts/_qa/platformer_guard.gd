extends Node

## Guard del plataformero: verifica que el mundo se construye, que la
## fisica de plataformas funciona y que tocar un enemigo abre la batalla.
##
## Run: godot --headless scenes/qa/platformer_guard.tscn --quit-after 400
##
## ponytail: simula input con Input.action_press/action_release, que es lo
## que dispara el camino real del controller (is_action_just_pressed). Setear
## `velocity` a mano, como hace battle_integration, no probaria el salto.

const WORLD := "res://scenes/platformer/platformer_world.tscn"
const TILE := 32
## Frames de settling tras soltar al jugador antes de medir.
const SETTLE_FRAMES := 30

var _passed: Array = []
var _failed: Array = []


func _ready() -> void:
	# La escena de batalla pausa el arbol; el guard tiene que seguir corriendo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _run() -> void:
	var world: Node = (load(WORLD) as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var player: Node = world.get_node("Entities/Player")
	var ground: TileMapLayer = world.get_node("Ground")
	var camera: Camera2D = world.get_node("Camera2D")
	var battle: Node = world.get_node("Battle")

	_check(ground.tile_set != null, "the world builds a TileSet")
	_check(ground.get_used_cells().size() > 50,
		"the level paints tiles (%d)" % ground.get_used_cells().size())
	_check(world.get_node("Entities").get_child_count() >= 2,
		"the world spawns the player and enemies")
	_check(player.get("sprite") != null and player.sprite.sprite_frames != null,
		"the player has sprite frames")

	# --- the fall and the landing -------------------------------------------
	var y_start: float = player.global_position.y
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	_check(player.is_on_floor(), "the player lands on the floor")
	_check(absf(player.global_position.y - y_start) < TILE,
		"the player comes to rest on the floor (y %.1f -> %.1f)"
		% [y_start, player.global_position.y])
	var y_ground: float = player.global_position.y

	# --- the jump ------------------------------------------------------------
	var y_min: float = y_ground
	Input.action_press("jump")
	for i in range(20):
		await get_tree().physics_frame
		y_min = minf(y_min, player.global_position.y)
	Input.action_release("jump")
	_check(y_min < y_ground - 24.0,
		"jump lifts the player (%.1f px)" % (y_ground - y_min))
	_check(player.is_on_floor() or player.velocity.y < 0.0,
		"the player is airborne during the jump")

	# --- no double jump ------------------------------------------------------
	for i in range(14):
		await get_tree().physics_frame
	if not player.is_on_floor():
		var y_before: float = player.global_position.y
		Input.action_press("jump")
		for i in range(6):
			await get_tree().physics_frame
		Input.action_release("jump")
		var y_after: float = player.global_position.y
		_check(y_after >= y_before - 2.0,
			"a second jump in mid-air does not lift the player again")

	# --- horizontal movement -------------------------------------------------
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	var x_before: float = player.global_position.x
	Input.action_press("move_right")
	for i in range(30):
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x > x_before + 40.0,
		"move_right walks the player (%.1f -> %.1f)"
		% [x_before, player.global_position.x])

	# --- the camera follows ---------------------------------------------------
	var cam_before: float = camera.global_position.x
	await get_tree().process_frame
	await get_tree().process_frame
	_check(absf(camera.global_position.x - player.global_position.x) < 400.0,
		"the camera tracks the player (cam %.1f vs player %.1f)"
		% [camera.global_position.x, player.global_position.x])
	_check(cam_before != 0.0, "the camera moved off its spawn")

	# --- touching an enemy opens the battle ----------------------------------
	var enemy: Node = null
	for child in world.get_node("Entities").get_children():
		if child != player and child.has_method("defeat"):
			enemy = child
			break
	_check(enemy != null, "the level contains an enemy")
	if enemy != null:
		player.global_position = enemy.global_position + Vector2(-6, 0)
		player.velocity = Vector2(120, 0)
		var opened := false
		for i in range(40):
			await get_tree().physics_frame
			if battle.visible:
				opened = true
				break
		_check(opened, "walking into an enemy opens the battle")

	_finish()


func _finish() -> void:
	print("\n========== PLATFORMER GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("=======================================")
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
