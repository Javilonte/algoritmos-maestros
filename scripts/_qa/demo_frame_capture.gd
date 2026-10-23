extends Node

# Runs the iso_demo.tscn scene inside a SubViewport and captures screenshots.
# Captures /tmp/demo_frame_XX.png every 100ms.

var _frame: int = 0


func _ready() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1152, 648)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	var demo: PackedScene = load("res://scenes/iso/iso_demo.tscn") as PackedScene
	if demo == null:
		push_error("Cannot load iso_demo.tscn")
		get_tree().quit(1)
		return
	var demo_root: Node = demo.instantiate()
	sv.add_child(demo_root)

	for i in range(60):
		get_tree().create_timer(0.1 + i * 0.1).timeout.connect(_capture.bind(i))


func _capture(idx: int) -> void:
	var sv := get_child(0) as SubViewport
	if sv == null:
		return
	var img: Image = sv.get_texture().get_image()
	if img:
		img.save_png("/tmp/demo_frame_%02d.png" % idx)
		print("captured frame %d" % idx)
	if idx == 59:
		get_tree().quit(0)
