extends CanvasLayer
class_name LevelUpToast

## ponytail: lightweight CanvasLayer that shows a brief "LEVEL UP!" banner
## when SkillTree.level_changed fires. Lives at layer 50 (above Battle at 9
## and HUD at 10). Auto-fades after SHOW_DURATION and is queue-able.
##
## Usage: LevelUpToast is a child of any scene that should surface level-ups
## (currently iso_demo.tscn). Connecting to SkillTree.level_changed is done
## by whoever instantiates the toast.

const SHOW_DURATION := 1.8  # seconds visible before fade
const SLIDE_IN_DURATION := 0.25
const FADE_OUT_DURATION := 0.4

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label
@onready var _level_label: Label = $Panel/LevelLabel

var _fade_tween: Tween = null


func _ready() -> void:
	# ponytail: stay hidden by default — show_level() is the only entry point.
	# CanvasLayer has no modulate; fade is applied to the inner Panel.
	visible = false
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())
	_label.add_theme_color_override("font_color", D2Palette.GOLD_TEXT_BRIGHT)
	_level_label.add_theme_color_override("font_color", D2Palette.BONE_TEXT)


## Connect this once after instantiation. Safe to call multiple times
## (idempotent on the SkillTree singleton).
func connect_to_skill_tree() -> void:
	if not SkillTree.level_changed.is_connected(_on_level_changed):
		SkillTree.level_changed.connect(_on_level_changed)


func _on_level_changed(new_level: int) -> void:
	show_level(new_level)


## Public entry point. Slides the banner in, holds, then fades out.
func show_level(new_level: int) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_label.text = "LEVEL UP!"
	_level_label.text = "Lv %d" % new_level
	visible = true
	# Start at the bottom of the screen, slide up + fade in.
	_panel.position.y = 40
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_panel, "modulate:a", 1.0, SLIDE_IN_DURATION)
	_fade_tween.tween_property(_panel, "position:y", 16, SLIDE_IN_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_tween.chain().tween_interval(SHOW_DURATION)
	_fade_tween.chain().tween_property(_panel, "modulate:a", 0.0, FADE_OUT_DURATION)
	_fade_tween.tween_callback(func() -> void: visible = false)
