class_name DamageNumber
extends Label

const TIER_COLORS := {
	"D": Color(0.6, 0.6, 0.6),
	"C": Color(0.8, 0.7, 0.4),
	"B": Color(0.4, 0.9, 0.4),
	"A": Color(0.4, 0.9, 0.9),
	"S": Color(1.0, 0.5, 1.0),
}

static func spawn(parent: Node, world_position: Vector2, roll: DamageRoll) -> void:
	var label := Label.new()
	label.text = "%d%s" % [roll.amount, " !" if roll.is_crit else ""]
	var color: Color = TIER_COLORS.get(roll.quality_tier, Color.WHITE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 44 if roll.is_crit else 32)
	label.z_index = 100
	parent.add_child(label)
	if parent is CanvasItem:
		label.global_position = world_position
	else:
		label.position = world_position

	var tween := label.create_tween().set_parallel(true)
	var rise := 80.0 if roll.is_crit else 60.0
	tween.tween_property(label, "position:y", label.position.y - rise, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	if roll.is_crit:
		var pulse := label.create_tween()
		pulse.tween_property(label, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
