extends PanelContainer
class_name MenuStatsPanel

## ponytail: right column of the redesigned main menu. Surfaces the
## player's progression at a glance:
##   - Level badge (sigil_neon_small) with Lv N
##   - XP bar (uses HPBar with side="xp" — reused component)
##   - Skills (N/Total) with cyan/locked dots
##   - Macros list (badges per unlocked macro)
##   - Enemies (N/Total)
##   - "No save" prompt if SkillTree is at level 1 AND no save exists
##
## Subscribes to SkillTree.skill_unlocked / xp_changed / level_changed
## so it stays live as the player progresses (only relevant if the menu
## is ever shown mid-session; today it's only on app boot).

const TOTAL_SKILLS := 14
const TOTAL_ENEMIES := 10

@export var show_save_prompt: bool = true

var _level_badge_label: Label
var _xp_bar: HPBar
var _xp_label: Label
var _skills_label: Label
var _skills_row: HBoxContainer
var _macros_label: Label
var _macros_row: HBoxContainer
var _enemies_label: Label
var _save_prompt: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", D2StyleBox.sigil_neon())
	_build()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Header: level badge + name.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(48, 28)
	badge.add_theme_stylebox_override("panel", D2StyleBox.sigil_neon_small())
	header.add_child(badge)
	var badge_box := CenterContainer.new()
	badge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge.add_child(badge_box)
	_level_badge_label = Label.new()
	_level_badge_label.text = "Lv 1"
	_level_badge_label.add_theme_color_override("font_color", D2Palette.NEON_CYAN)
	_level_badge_label.add_theme_font_size_override("font_size", 14)
	badge_box.add_child(_level_badge_label)

	_xp_label = Label.new()
	_xp_label.text = "0 XP"
	_xp_label.add_theme_color_override("font_color", D2Palette.BONE_TEXT)
	_xp_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_xp_label)

	# XP bar.
	_xp_bar = HPBar.new()
	_xp_bar.side = "xp"
	_xp_bar.custom_minimum_size = Vector2(0, 12)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	vbox.add_child(_xp_bar)

	# Skills section.
	_skills_label = Label.new()
	_skills_label.text = "SKILLS"
	_skills_label.add_theme_color_override("font_color", D2Palette.NEON_CYAN)
	_skills_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_skills_label)
	_skills_row = HBoxContainer.new()
	_skills_row.add_theme_constant_override("separation", 4)
	_skills_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_skills_row)

	# Macros section.
	_macros_label = Label.new()
	_macros_label.text = "MACROS"
	_macros_label.add_theme_color_override("font_color", D2Palette.NEON_CYAN)
	_macros_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_macros_label)
	_macros_row = HBoxContainer.new()
	_macros_row.add_theme_constant_override("separation", 4)
	_macros_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_macros_row)

	# Enemies section.
	_enemies_label = Label.new()
	_enemies_label.text = "ENEMIES"
	_enemies_label.add_theme_color_override("font_color", D2Palette.NEON_CYAN)
	_enemies_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_enemies_label)

	# Save prompt (only shown when no save).
	_save_prompt = Label.new()
	_save_prompt.text = "Sin partida guardada\nComienza tu viaje"
	_save_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_prompt.add_theme_color_override("font_color", D2Palette.MUTED_TEXT)
	_save_prompt.add_theme_font_size_override("font_size", 11)
	_save_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD
	_save_prompt.visible = show_save_prompt
	vbox.add_child(_save_prompt)


## ponytail: refresh from SkillTree. Safe to call when the autoload
## is missing (the menu is shown at app boot, before SkillTree may
## be ready in some edge cases).
func refresh_from_skill_tree() -> void:
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		# ponytail: SkillTree is the autoload; if missing we can't
		# render real stats. Show the "no save" prompt as a fallback.
		_apply_no_save_state()
		return

	var level: int = int(st.get("current_level")) if "current_level" in st else 1
	var xp: int = int(st.get("current_xp")) if "current_xp" in st else 0
	if _level_badge_label:
		_level_badge_label.text = "Lv %d" % level
	if _xp_label:
		_xp_label.text = "%d XP" % xp
	# Update XP bar to (current / to_next) ratio.
	if _xp_bar:
		var to_next: int = int(st._xp_for_next_level()) if st.has_method("_xp_for_next_level") else 100
		_xp_bar.max_value = max(1, to_next)
		_xp_bar.value = clamp(xp, 0, to_next)

	_refresh_skills(st)
	_refresh_macros(st)
	_refresh_enemies(st)
	_refresh_save_prompt()


## ponytail: connect to SkillTree signals (idempotent).
func connect_to_skill_tree() -> void:
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		return
	for sig_name in ["skill_unlocked", "level_changed", "xp_changed"]:
		if st.has_signal(sig_name) and not st.get(sig_name).is_connected(_on_skill_tree_signal):
			st.get(sig_name).connect(_on_skill_tree_signal)
	refresh_from_skill_tree()


func _on_skill_tree_signal(_a = null, _b = null, _c = null) -> void:
	refresh_from_skill_tree()


func _refresh_skills(st: Node) -> void:
	if _skills_row == null:
		return
	# Clear existing dots.
	for child in _skills_row.get_children():
		child.queue_free()
	var unlocked: int = 0
	if st.has_method("skills"):
		var skills_dict: Dictionary = st.skills
		for id in skills_dict:
			var n: SkillNode = skills_dict[id]
			if n.unlocked:
				unlocked += 1
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(12, 12)
			dot.add_theme_stylebox_override("panel", D2StyleBox.skill_dot_unlocked() if n.unlocked else D2StyleBox.skill_dot_locked())
			_skills_row.add_child(dot)
	if _skills_label:
		_skills_label.text = "SKILLS (%d/%d)" % [unlocked, TOTAL_SKILLS]


func _refresh_macros(st: Node) -> void:
	if _macros_row == null:
		return
	for child in _macros_row.get_children():
		child.queue_free()
	var macros: PackedStringArray = PackedStringArray()
	if st.has_method("get_unlocked_macros"):
		macros = st.get_unlocked_macros()
	for m in macros:
		var badge := Panel.new()
		badge.add_theme_stylebox_override("panel", D2StyleBox.sigil_neon_small())
		var box := CenterContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		badge.add_child(box)
		var label := Label.new()
		label.text = String(m)
		label.add_theme_color_override("font_color", D2Palette.NEON_CYAN)
		label.add_theme_font_size_override("font_size", 10)
		box.add_child(label)
		_macros_row.add_child(badge)
	if _macros_label:
		_macros_label.text = "MACROS (%d)" % macros.size()


func _refresh_enemies(st: Node) -> void:
	if _enemies_label == null:
		return
	var unlocked: int = 0
	if st.has_method("get_unlocked_enemies"):
		var enemies: PackedStringArray = st.get_unlocked_enemies()
		unlocked = enemies.size()
	_enemies_label.text = "ENEMIES (%d/%d)" % [unlocked, TOTAL_ENEMIES]


func _refresh_save_prompt() -> void:
	if _save_prompt == null:
		return
	var has_save: bool = false
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("has_save"):
		has_save = sm.has_save()
	_save_prompt.visible = show_save_prompt and not has_save


func _apply_no_save_state() -> void:
	if _level_badge_label:
		_level_badge_label.text = "Lv 1"
	if _xp_label:
		_xp_label.text = "0 XP"
	if _xp_bar:
		_xp_bar.value = 0
	for child in _skills_row.get_children():
		child.queue_free()
	for child in _macros_row.get_children():
		child.queue_free()
	if _skills_label:
		_skills_label.text = "SKILLS (0/%d)" % TOTAL_SKILLS
	if _macros_label:
		_macros_label.text = "MACROS (0)"
	if _enemies_label:
		_enemies_label.text = "ENEMIES (0/%d)" % TOTAL_ENEMIES
	_refresh_save_prompt()
