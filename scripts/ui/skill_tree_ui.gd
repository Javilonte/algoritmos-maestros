extends Control
class_name SkillTreeUI

## Visualización del Skill Tree estilo Diablo II.
## Layout: árbol jerárquico de izquierda a derecha.
##   root → branch_pointers   branch_stl → fusion → recursion / templates / concurrency → final_boss

signal skill_unlock_requested(skill_id: StringName)

const NODE_WIDTH := 180
const NODE_HEIGHT := 70
const H_SPACING := 200
const V_SPACING := 110

var _tree: SkillTreeData
var _node_panels: Dictionary = {}  # id -> Panel

@onready var outer_frame: Panel = $OuterFrame
@onready var inner_panel: Panel = $OuterFrame/InnerPanel
@onready var header_bar: Panel = $OuterFrame/InnerPanel/HeaderBar
@onready var close_button: Button = $OuterFrame/InnerPanel/HeaderBar/CloseButton
@onready var canvas: Control = $OuterFrame/InnerPanel/Scroll/Canvas

var _positions: Dictionary = {}

func _ready() -> void:
	_apply_responsive_layout()
	_apply_local_overrides()
	_tree = get_node_or_null("/root/SkillTree") as SkillTreeData
	if _tree:
		_tree.skill_unlocked.connect(_refresh_all)
	close_button.pressed.connect(_on_close_pressed)
	_compute_layout()
	_build_connections()
	_build_nodes()
	_refresh_all()

func _apply_responsive_layout() -> void:
	if outer_frame == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var w: float = clampf(vp.x - UIMetrics.VIEWPORT_MARGIN * 2, 800, UIMetrics.SKILLTREE_WIDTH)
	var h: float = clampf(vp.y - UIMetrics.VIEWPORT_MARGIN * 2, 480, UIMetrics.SKILLTREE_HEIGHT)
	outer_frame.size = Vector2(w, h)
	outer_frame.position = (vp - Vector2(w, h)) * 0.5
	# Ajustar canvas interno al tamano del tree.
	if canvas:
		canvas.custom_minimum_size = Vector2(maxf(UIMetrics.SKILLTREE_WIDTH, w - 32), maxf(UIMetrics.SKILLTREE_HEIGHT - 80, h - 80))

func _apply_local_overrides() -> void:
	if outer_frame:
		outer_frame.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())
	if inner_panel:
		inner_panel.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
	if header_bar:
		header_bar.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())

func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _compute_layout() -> void:
	# Layout manual: posiciones fijas por id (diagrama horizontal).
	_positions = {
		&"root_arithmetic": Vector2(40, 270),
		&"branch_pointers": Vector2(240, 150),
		&"branch_stl": Vector2(240, 410),
		&"ptr_if_else": Vector2(440, 90),
		&"ptr_arrays": Vector2(640, 50),
		&"ptr_dynamic": Vector2(840, 90),
		&"stl_loops": Vector2(440, 350),
		&"stl_functions": Vector2(640, 390),
		&"stl_containers": Vector2(840, 350),
		&"fusion": Vector2(1040, 220),
		&"recursion": Vector2(1240, 90),
		&"templates": Vector2(1240, 220),
		&"concurrency": Vector2(1240, 350),
		&"final_boss": Vector2(1440, 220),
	}

func _build_connections() -> void:
	if _tree == null:
		return
	for id in _tree.skills:
		var node: SkillNode = _tree.skills[id]
		var to_pos: Vector2 = _positions.get(id, Vector2.ZERO) + Vector2(NODE_WIDTH * 0.5, NODE_HEIGHT * 0.5)
		for dep in node.depends_on:
			var from_pos: Vector2 = _positions.get(dep, Vector2.ZERO) + Vector2(NODE_WIDTH, NODE_HEIGHT * 0.5)
			var line := Line2D.new()
			line.add_point(from_pos)
			line.add_point(to_pos)
			line.width = 2.0
			line.default_color = D2Palette.BRONZE_DARK
			line.modulate = Color(1, 1, 1, 0.7)
			canvas.add_child(line)

func _build_nodes() -> void:
	if _tree == null:
		return
	for id in _tree.skills:
		var n: SkillNode = _tree.skills[id]
		var pos: Vector2 = _positions.get(id, Vector2.ZERO)
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(NODE_WIDTH, NODE_HEIGHT)
		panel.position = pos
		canvas.add_child(panel)
		_node_panels[id] = panel

		# Nombre del skill.
		var name_label := Label.new()
		name_label.text = n.display_name
		name_label.position = Vector2(8, 6)
		name_label.size = Vector2(NODE_WIDTH - 16, 28)
		name_label.add_theme_color_override("font_color", D2Palette.BONE_TEXT)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.horizontal_alignment = 1
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		panel.add_child(name_label)

		# Costo en XP (esquina inferior derecha).
		var cost_label := Label.new()
		cost_label.text = "%d XP" % n.cost_xp
		cost_label.position = Vector2(NODE_WIDTH - 64, NODE_HEIGHT - 22)
		cost_label.size = Vector2(58, 18)
		cost_label.add_theme_color_override("font_color", D2Palette.XP_BLUE_HI)
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.horizontal_alignment = 2
		panel.add_child(cost_label)

		# Botón invisible encima del panel para detectar clicks.
		var btn := Button.new()
		btn.text = ""
		btn.position = Vector2.ZERO
		btn.size = Vector2(NODE_WIDTH, NODE_HEIGHT)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_node_pressed.bind(id))
		panel.add_child(btn)

func _on_node_pressed(skill_id: StringName) -> void:
	if _tree == null:
		return
	if _tree.try_unlock(skill_id):
		skill_unlock_requested.emit(skill_id)
		_refresh_all()
	else:
		_flash_locked(skill_id)

func _flash_locked(skill_id: StringName) -> void:
	var panel: Panel = _node_panels.get(skill_id)
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", D2StyleBox.button_pressed())
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(func() -> void: _refresh_node_style(skill_id))

func _refresh_all() -> void:
	for id in _node_panels:
		_refresh_node_style(id)

func _refresh_node_style(skill_id: StringName) -> void:
	if _tree == null:
		return
	var n: SkillNode = _tree.skills[skill_id]
	var panel: Panel = _node_panels[skill_id]
	if n == null or panel == null:
		return
	if n.unlocked:
		panel.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
		panel.modulate = Color(1, 1, 1, 1)
	elif _tree.can_unlock(skill_id):
		panel.add_theme_stylebox_override("panel", D2StyleBox.button_hover())
		panel.modulate = Color(1, 1, 1, 1)
	else:
		panel.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())
		panel.modulate = Color(0.55, 0.50, 0.45, 1.0)