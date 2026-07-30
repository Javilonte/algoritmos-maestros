extends RefCounted
class_name CyberpunkButton

## ponytail: static helpers that animate a Button between its normal
## (D2 bronze) and "neon" (cyan glow) appearance. Used by MenuActionButton
## to give a subtle "active UI" feel on hover/press without per-instance
## StyleBox allocations.
##
## The animations are short (80ms) and disabled when the user has
## reduced-motion preferences (a global flag we keep for future use).

const HOVER_DURATION := 0.08
const PRESS_DURATION := 0.06

var _tween: Tween = null
var _owner: Control
var _normal_scale: float = 1.0
var _reduced_motion: bool = false


static func make_hoverable(button: Button, normal_scale: float = 1.0) -> CyberpunkButton:
	# ponytail: factory ensures one wrapper per button — multiple calls
	# would create competing tweens.
	if button.has_meta("cyberpunk_wrapper"):
		var existing_v: Variant = button.get_meta("cyberpunk_wrapper")
		if existing_v is CyberpunkButton:
			return existing_v
	var wrapper: CyberpunkButton = CyberpunkButton.new()
	wrapper._owner = button
	wrapper._normal_scale = normal_scale
	button.set_meta("cyberpunk_wrapper", wrapper)
	button.mouse_entered.connect(wrapper._on_mouse_entered)
	button.mouse_exited.connect(wrapper._on_mouse_exited)
	button.button_down.connect(wrapper._on_button_down)
	button.button_up.connect(wrapper._on_button_up)
	button.focus_entered.connect(wrapper._on_focus_entered)
	button.focus_exited.connect(wrapper._on_focus_exited)
	return wrapper


func set_reduced_motion(reduced: bool) -> void:
	_reduced_motion = reduced


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_mouse_entered() -> void:
	if _owner == null or _reduced_motion:
		return
	_kill_tween()
	_owner.scale = Vector2(_normal_scale, _normal_scale)
	_tween = _owner.create_tween()
	_tween.tween_property(_owner, "scale", Vector2(_normal_scale * 1.04, _normal_scale * 1.04), HOVER_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	if _owner == null or _reduced_motion:
		return
	_kill_tween()
	_tween = _owner.create_tween()
	_tween.tween_property(_owner, "scale", Vector2(_normal_scale, _normal_scale), HOVER_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_button_down() -> void:
	if _owner == null or _reduced_motion:
		return
	_kill_tween()
	_tween = _owner.create_tween()
	_tween.tween_property(_owner, "scale", Vector2(_normal_scale * 0.96, _normal_scale * 0.96), PRESS_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_button_up() -> void:
	if _owner == null or _reduced_motion:
		return
	_kill_tween()
	_tween = _owner.create_tween()
	_tween.tween_property(_owner, "scale", Vector2(_normal_scale * 1.04, _normal_scale * 1.04), PRESS_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_focus_entered() -> void:
	if _owner == null:
		return
	# ponytail: keyboard focus gets the same hover treatment. Tracked
	# separately so screen-reader users see the visual cue.
	_on_mouse_entered()


func _on_focus_exited() -> void:
	if _owner == null:
		return
	_on_mouse_exited()
