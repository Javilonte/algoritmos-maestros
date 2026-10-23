extends Control
class_name BattleBanner

## ponytail: brief nameplate that fades in at battle start, holds for
## HOLD_DURATION, then fades out. Used to surface boss encounters with
## "BOSS ENCOUNTERED" style framing. Lives as a child of the BattleArena.
##
## Auto-frees after the fade so callers don't have to manage cleanup.

const HOLD_DURATION := 1.5
const SLIDE_IN_DURATION := 0.3
const FADE_OUT_DURATION := 0.5

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/TitleLabel
@onready var _subtitle: Label = $Panel/SubtitleLabel

var _fade_tween: Tween = null


func _ready() -> void:
	_apply_style()
	visible = false
	modulate = Color(1, 1, 1, 0)


func _apply_style() -> void:
	_panel.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())
	_title.add_theme_color_override("font_color", D2Palette.DANGER_TEXT)
	_subtitle.add_theme_color_override("font_color", D2Palette.BONE_TEXT)


func show_banner(title: String, subtitle: String = "") -> void:
	_title.text = title
	_subtitle.text = subtitle
	visible = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	# Scale-pop entrance.
	_panel.scale = Vector2(0.8, 0.8)
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(self, "modulate:a", 1.0, SLIDE_IN_DURATION)
	_fade_tween.tween_property(_panel, "scale", Vector2.ONE, SLIDE_IN_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_tween.chain().tween_interval(HOLD_DURATION)
	_fade_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	_fade_tween.tween_callback(queue_free)
