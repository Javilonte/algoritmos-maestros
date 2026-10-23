extends PanelContainer
class_name MenuHeroCard

## ponytail: left column of the redesigned main menu. Shows the
## player character idle in a sigil with a name/level strip below.
## Auto-binds to a SpriteFrames resource and listens to SkillTree
## changes so the name reflects the current level/XP.

@export var sprite_frames: SpriteFrames
@export var default_name: String = "Player"

var _sprite: AnimatedSprite2D
var _name_label: Label
var _level_label: Label
var _subtitle_label: Label
var _sigil_panel: Panel


func _ready() -> void:
	add_theme_stylebox_override("panel", D2StyleBox.sigil_neon())
	_build()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Sigil panel containing the AnimatedSprite2D.
	_sigil_panel = Panel.new()
	_sigil_panel.custom_minimum_size = Vector2(180, 220)
	_sigil_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sigil_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sigil_panel.add_theme_stylebox_override("panel", D2StyleBox.code_inner())
	var sigil_center := CenterContainer.new()
	sigil_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sigil_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sigil_panel.add_child(sigil_center)

	if sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = sprite_frames
		_sprite.scale = Vector2(0.4, 0.4)
		_sprite.autoplay = "idle"
		_sprite.animation = "idle"
		sigil_center.add_child(_sprite)
	vbox.add_child(_sigil_panel)

	# Header row: name + level badge.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.text = default_name
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", D2Palette.NEON_CYAN)
	_name_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_name_label)

	_level_label = Label.new()
	_level_label.text = "Lv 1"
	_level_label.add_theme_color_override("font_color", D2Palette.GOLD_TEXT_BRIGHT)
	_level_label.add_theme_font_size_override("font_size", 13)
	header.add_child(_level_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Sin partida guardada"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", D2Palette.MUTED_TEXT)
	_subtitle_label.add_theme_font_size_override("font_size", 11)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_subtitle_label)


## ponytail: refresh from SkillTree. Safe to call before the autoload
## is ready (returns silently).
func refresh_from_skill_tree() -> void:
	if not Engine.has_singleton("SkillTree") and get_node_or_null("/root/SkillTree") == null:
		return
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		return
	var level: int = int(st.get("current_level")) if "current_level" in st else 1
	var xp: int = int(st.get("current_xp")) if "current_xp" in st else 0
	if _level_label:
		_level_label.text = "Lv %d · %d XP" % [level, xp]
	if _subtitle_label:
		_subtitle_label.text = "Tu viaje por los algoritmos"


## ponytail: connect to SkillTree once (call after instantiation).
func connect_to_skill_tree() -> void:
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		return
	if st.has_signal("level_changed") and not st.level_changed.is_connected(_on_level_changed):
		st.level_changed.connect(_on_level_changed)
	if st.has_signal("xp_changed") and not st.xp_changed.is_connected(_on_xp_changed):
		st.xp_changed.connect(_on_xp_changed)
	refresh_from_skill_tree()


func _on_level_changed(_new_level: int) -> void:
	refresh_from_skill_tree()


func _on_xp_changed(_current: int, _to_next: int) -> void:
	refresh_from_skill_tree()
