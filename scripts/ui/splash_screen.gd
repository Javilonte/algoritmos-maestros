extends Control

const MAIN_MENU_PATH := "res://scenes/main_menu/main_menu.tscn"
const CUBE_SIZE := 0.22
const LETTER_SPACING := 0.6

const LETTER_A: Array[String] = [
	".XXX.",
	"X...X",
	"X...X",
	"XXXXX",
	"X...X",
	"X...X",
	"X...X",
]

const LETTER_M: Array[String] = [
	"X...X",
	"XX.XX",
	"X.X.X",
	"X...X",
	"X...X",
	"X...X",
	"X...X",
]

const FULL_TEXT := "ALGORITMOS MAESTROS"
const SUB_TEXT := "> system ready."
const TYPE_PER_CHAR := 0.055

@onready var background: ColorRect = $Background
@onready var pixel_grid: TextureRect = $PixelGrid
@onready var voxel_camera: Camera3D = $VoxelViewport/SubViewport/VoxelCamera
@onready var voxel_logo: Node3D = $VoxelViewport/SubViewport/VoxelLogo
@onready var scanline: ColorRect = $Scanline
@onready var logo_text: Label = $LogoText
@onready var sub_text: Label = $SubText
@onready var skip_hint: Label = $SkipHint
@onready var cursor_label: Label = $CursorBlink
@onready var cursor_timer: Timer = $CursorTimer

var _cubes: Array[MeshInstance3D] = []
var _cubes_target_x: Array[float] = []
var _cubes_target_y: Array[float] = []
var _cubes_target_z: Array[float] = []
var _cubes_fall_delay: Array[float] = []
var _skipped: bool = false
var _accept_input: bool = true

func _ready() -> void:
	background.modulate.a = 0.0
	logo_text.text = ""
	logo_text.modulate.a = 1.0
	sub_text.text = ""
	sub_text.modulate.a = 0.0
	skip_hint.modulate.a = 0.7

	pixel_grid.texture = _build_pixel_grid_texture(64, 36)
	_build_voxel_logo()

	_start_scanline_loop()
	_start_skip_hint_blink()
	_run_timeline()

func _build_pixel_grid_texture(grid_w: int, grid_h: int) -> ImageTexture:
	var img := Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in grid_w:
		img.set_pixel(x, 0, Color(0.1, 0.6, 0.3, 0.20))
		img.set_pixel(x, grid_h - 1, Color(0.1, 0.6, 0.3, 0.08))
	for y in grid_h:
		img.set_pixel(0, y, Color(0.1, 0.6, 0.3, 0.14))
		img.set_pixel(grid_w - 1, y, Color(0.1, 0.6, 0.3, 0.05))
	for y in range(2, grid_h - 2, 4):
		for x in range(2, grid_w - 2, 4):
			img.set_pixel(x, y, Color(0.1, 0.3, 0.2, 0.05))
	return ImageTexture.create_from_image(img)

func _build_voxel_logo() -> void:
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(CUBE_SIZE, CUBE_SIZE, CUBE_SIZE)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.05, 0.07, 1)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.9, 0.4, 1)
	mat.emission_energy_multiplier = 0.4
	mat.roughness = 0.6
	mat.metallic = 0.0

	var offset_x := 0.0
	for letter in [LETTER_A, LETTER_M]:
		_spawn_letter(letter, cube_mesh, mat, offset_x)
		offset_x += LETTER_SPACING

func _spawn_letter(letter: Array[String], cube_mesh: BoxMesh, mat: StandardMaterial3D, offset_x: float) -> void:
	var letter_width := letter[0].length()
	var letter_height := letter.size()
	var letter_origin_x := -(letter_width * CUBE_SIZE) * 0.5
	var letter_origin_y := -(letter_height * CUBE_SIZE) * 0.5

	for y in letter_height:
		var row: String = letter[y]
		for x in letter_width:
			if row[x] != "X":
				continue
			var cube := MeshInstance3D.new()
			cube.mesh = cube_mesh
			cube.material_override = mat
			var final_x := letter_origin_x + x * CUBE_SIZE + offset_x
			var final_y := letter_origin_y + (letter_height - 1 - y) * CUBE_SIZE
			var final_z := 0.0
			cube.position = Vector3(
				final_x,
				final_y + 10.0 + randf() * 4.0,
				final_z + randf_range(-0.5, 0.5)
			)
			cube.rotation = Vector3(randf() * 0.5, randf() * 0.5, randf() * 0.5)
			cube.scale = Vector3(0.01, 0.01, 0.01)
			voxel_logo.add_child(cube)
			_cubes.append(cube)
			_cubes_target_x.append(final_x)
			_cubes_target_y.append(final_y)
			_cubes_target_z.append(final_z)
			_cubes_fall_delay.append(randf() * 0.3)

func _start_scanline_loop() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(scanline, "offset_top", 720.0, 5.0).from(-2.0)
	tween.parallel().tween_property(scanline, "offset_bottom", 722.0, 5.0).from(0.0)

func _start_skip_hint_blink() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(skip_hint, "modulate:a", 1.0, 0.6)
	tween.tween_property(skip_hint, "modulate:a", 0.4, 0.6)

func _run_timeline() -> void:
	# 0.0s: fade-in background
	var bg_tween := create_tween()
	bg_tween.tween_property(background, "modulate:a", 1.0, 0.3)

	# 0.3s: cubes fall with stagger
	await get_tree().create_timer(0.3).timeout
	if _skipped:
		return
	_animate_cubes_fall()

	# 1.4s: cubes snap into place, camera shake
	await get_tree().create_timer(1.1).timeout
	if _skipped:
		return
	_snap_cubes_to_target()
	_shake_camera()

	# 1.8s: type-on title
	await get_tree().create_timer(0.4).timeout
	if _skipped:
		return
	await _type_text(logo_text, FULL_TEXT, TYPE_PER_CHAR)

	# subtitle fade-in
	if _skipped:
		return
	sub_text.text = SUB_TEXT
	var sub_tween := create_tween()
	sub_tween.tween_property(sub_text, "modulate:a", 1.0, 0.35)

	# glitch pass
	await get_tree().create_timer(0.3).timeout
	if _skipped:
		return
	await _glitch_pass()

	# final fade-out + transition
	await get_tree().create_timer(0.2).timeout
	_fade_to_menu()

func _animate_cubes_fall() -> void:
	for i in _cubes.size():
		var cube := _cubes[i]
		if not is_instance_valid(cube):
			continue
		var delay := _cubes_fall_delay[i]
		var target := Vector3(_cubes_target_x[i], _cubes_target_y[i], _cubes_target_z[i])
		_animate_single_cube(cube, target, delay)

func _animate_single_cube(cube: MeshInstance3D, target: Vector3, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(cube) or _skipped:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(cube, "position", target, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(cube, "rotation", Vector3.ZERO, 0.55).set_trans(Tween.TRANS_QUAD)
	t.tween_property(cube, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _snap_cubes_to_target() -> void:
	for i in _cubes.size():
		var cube := _cubes[i]
		if not is_instance_valid(cube):
			continue
		cube.position = Vector3(_cubes_target_x[i], _cubes_target_y[i], _cubes_target_z[i])
		cube.rotation = Vector3.ZERO
		cube.scale = Vector3.ONE

func _shake_camera() -> void:
	var original_pos := voxel_camera.position
	var tween := create_tween()
	tween.tween_property(voxel_camera, "position", original_pos + Vector3(0.06, 0, 0), 0.04)
	tween.tween_property(voxel_camera, "position", original_pos + Vector3(-0.06, 0.02, 0), 0.04)
	tween.tween_property(voxel_camera, "position", original_pos + Vector3(0.04, -0.02, 0), 0.04)
	tween.tween_property(voxel_camera, "position", original_pos, 0.06)

func _type_text(label: Label, full: String, per_char: float) -> void:
	label.text = ""
	for i in full.length():
		if _skipped:
			label.text = full
			return
		label.text = full.substr(0, i + 1)
		await get_tree().create_timer(per_char).timeout

func _glitch_pass() -> void:
	var original_x := logo_text.position.x
	var tween := create_tween()
	tween.tween_property(logo_text, "position:x", original_x + 7.0, 0.05)
	tween.tween_property(logo_text, "modulate:a", 0.35, 0.04)
	tween.tween_property(logo_text, "position:x", original_x - 7.0, 0.05)
	tween.tween_property(logo_text, "modulate:a", 1.0, 0.04)
	tween.tween_property(logo_text, "position:x", original_x + 3.0, 0.04)
	tween.tween_property(logo_text, "modulate:a", 0.7, 0.03)
	tween.tween_property(logo_text, "position:x", original_x, 0.05)
	tween.tween_property(logo_text, "modulate:a", 1.0, 0.05)
	await tween.finished

func _fade_to_menu() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _skip_to_menu() -> void:
	if _skipped:
		return
	_skipped = true
	_snap_cubes_to_target()
	logo_text.text = FULL_TEXT
	logo_text.modulate.a = 1.0
	sub_text.text = SUB_TEXT
	sub_text.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	await t.finished
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _input(event: InputEvent) -> void:
	if not _accept_input or _skipped:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_skip_to_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_skip_to_menu()
		get_viewport().set_input_as_handled()

func _on_cursor_timer_timeout() -> void:
	if cursor_label != null:
		cursor_label.visible = not cursor_label.visible
