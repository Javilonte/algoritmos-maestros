extends PanelContainer
class_name BattlePortrait

## A single battle portrait: name + level badge + animated sprite + HP bar.
##
## Used for both the player and the enemy in BattleArena. The portrait
## shows the character's idle animation by default and switches to
## `hurt` briefly when taking damage (`flash_hurt()`).
##
## ponytail: sized to fit a 344x280 (player) or 320x320 (crow) frame
## at scale 0.45. Layout uses nested VBox / HBox containers so the
## header, sigil, and HP bar stack vertically with proportional sizing.

@export var sprite_frames: SpriteFrames
@export var idle_anim: StringName = &"idle"
@export var hurt_anim: StringName = &"hurt"
@export var portrait_scale: float = 0.45
@export var display_name: String = "???"
@export var level: int = 1
@export var side: String = "enemy"  # "enemy" or "player"

var _sprite: AnimatedSprite2D
var _name_label: Label
var _level_label: Label
var _hp_bar: HPBar
var _sigil: Panel
var _default_anim: StringName


func _ready() -> void:
	_apply_style()
	_build()


func _apply_style() -> void:
	add_theme_stylebox_override("panel", D2StyleBox.sigil())


func _build() -> void:
	# Inner column: name+level row, sigil with sprite, HP bar.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Header row: name + level badge.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.text = display_name
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", D2Palette.GOLD_TEXT_BRIGHT)
	_name_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_name_label)

	_level_label = Label.new()
	_level_label.text = "Lv %d" % level
	_level_label.add_theme_color_override("font_color", D2Palette.BONE_TEXT)
	_level_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_level_label)

	# Sigil panel containing the AnimatedSprite2D.
	_sigil = Panel.new()
	_sigil.custom_minimum_size = Vector2(160, 180)
	_sigil.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sigil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sigil.add_theme_stylebox_override("panel", D2StyleBox.code_inner())
	var sigil_center := CenterContainer.new()
	sigil_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sigil_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sigil.add_child(sigil_center)

	if sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = sprite_frames
		_sprite.scale = Vector2(portrait_scale, portrait_scale)
		_sprite.autoplay = String(idle_anim)
		_sprite.animation = String(idle_anim)
		sigil_center.add_child(_sprite)
		_default_anim = idle_anim
	vbox.add_child(_sigil)

	# HP bar.
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hp_row)

	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_color_override("font_color", D2Palette.MUTED_TEXT)
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_row.add_child(hp_label)

	_hp_bar = HPBar.new()
	_hp_bar.side = side
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size = Vector2(0, 14)
	hp_row.add_child(_hp_bar)


## Update the displayed name and level.
func set_identity(name: String, p_level: int) -> void:
	display_name = name
	level = p_level
	if _name_label:
		_name_label.text = name
	if _level_label:
		_level_label.text = "Lv %d" % p_level


## Update the HP bar.
func set_hp(current: int, max_hp: int) -> void:
	if _hp_bar:
		_hp_bar.set_hp(current, max_hp)


## Briefly play the `hurt` animation then return to idle.
func flash_hurt() -> void:
	if _sprite == null or sprite_frames == null:
		return
	if not sprite_frames.has_animation(hurt_anim):
		return
	_sprite.play(hurt_anim)
	await get_tree().create_timer(0.4).timeout
	if _sprite != null:
		_sprite.play(_default_anim)
