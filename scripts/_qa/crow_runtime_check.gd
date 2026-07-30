extends SceneTree

## ponytail: runtime check that the on-disk crow_enemy.tscn has the
## expected HitShape radius. Catches the "user ran the game without
## re-importing" failure mode.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/iso/crow_enemy.tscn") as PackedScene
	if scene == null:
		print("FAIL: cannot load crow_enemy.tscn")
		quit(1)
		return
	var root: Node = scene.instantiate()
	get_root().add_child(root)
	await process_frame

	var hit_area: Area2D = root.get_node_or_null("HitArea")
	if hit_area == null:
		print("FAIL: HitArea not found")
		quit(1)
		return
	var hit_shape: CollisionShape2D = hit_area.get_node_or_null("HitShape")
	if hit_shape == null:
		print("FAIL: HitShape not found")
		quit(1)
		return
	var shape: CircleShape2D = hit_shape.shape as CircleShape2D
	print("HitShape radius: ", shape.radius)
	if shape.radius == 80.0:
		print("PASS: HitShape radius is 80")
		quit(0)
	else:
		print("FAIL: expected radius 80")
		quit(1)
