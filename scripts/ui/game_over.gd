extends Control
class_name GameOver

## ponytail: shown after Battle._end_battle("lose"). Losing is not free
## and not free the other way either, so both options state their price:
##   - Retry: re-open the BattleTerminal with both HP pools full, but the
##     combo streak resets (GameManager.start_battle zeroes it).
##   - Run away: return to the overworld, but the enemy is defeated and
##     stays gone for its own respawn_time, so it cannot be re-fought
##     immediately to farm XP.
##
## The screen is a standalone Control, not a CanvasLayer, so the caller
## (Battle) is responsible for adding it to the tree and positioning it.

signal retry_pressed
signal run_pressed

@onready var _title: Label = $CenterContainer/VBox/Title
@onready var _subtitle: Label = $CenterContainer/VBox/Subtitle
@onready var _retry_button: Button = $CenterContainer/VBox/ButtonRow/RetryButton
@onready var _run_button: Button = $CenterContainer/VBox/ButtonRow/RunButton

var _challenge_id: StringName = &""


func _ready() -> void:
	_apply_style()
	_retry_button.pressed.connect(_on_retry_pressed)
	_run_button.pressed.connect(_on_run_pressed)


func _apply_style() -> void:
	_retry_button.add_theme_stylebox_override("normal", D2StyleBox.button_normal())
	_retry_button.add_theme_stylebox_override("hover", D2StyleBox.button_hover())
	_retry_button.add_theme_stylebox_override("pressed", D2StyleBox.button_pressed())
	_run_button.add_theme_stylebox_override("normal", D2StyleBox.button_normal())
	_run_button.add_theme_stylebox_override("hover", D2StyleBox.button_hover())
	_run_button.add_theme_stylebox_override("pressed", D2StyleBox.button_pressed())
	_title.add_theme_color_override("font_color", D2Palette.DANGER_TEXT)
	_subtitle.add_theme_color_override("font_color", D2Palette.BONE_TEXT)


## Set the metadata before showing.
func setup(challenge_id: StringName, enemy_name: String, respawn_seconds: int = 30) -> void:
	_challenge_id = challenge_id
	# ponytail: a cost the player cannot see is not a mechanic, so both
	# prices are spelled out. respawn_seconds comes from the enemy node,
	# not a constant, so the promise matches the real timer.
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.text = "Derrotado por %s\nReintentar: pierdes el combo · Huir: vuelve en %ds" % [
		enemy_name, respawn_seconds,
	]
	_run_button.text = "Huir (%ds)" % respawn_seconds
	_retry_button.tooltip_text = "HP y enemigo al máximo. Pierdes tu racha de combo."
	_run_button.tooltip_text = "Vuelves al overworld. El enemigo reaparece en %ds." % respawn_seconds


func _on_retry_pressed() -> void:
	retry_pressed.emit()
	queue_free()


func _on_run_pressed() -> void:
	run_pressed.emit()
	queue_free()


## ponytail: expose the challenge id so Battle can re-open the terminal.
func get_challenge_id() -> StringName:
	return _challenge_id
