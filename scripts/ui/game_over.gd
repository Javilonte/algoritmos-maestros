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

@onready var _title: Label = $CenterContainer/Panel/VBox/Title
@onready var _subtitle: Label = $CenterContainer/Panel/VBox/Subtitle
@onready var _retry_button: Button = $CenterContainer/Panel/VBox/ButtonRow/RetryButton
@onready var _run_button: Button = $CenterContainer/Panel/VBox/ButtonRow/RunButton
@onready var _panel: PanelContainer = $CenterContainer/Panel
@onready var _dim: ColorRect = $Dim

var _challenge_id: StringName = &""


func _ready() -> void:
	_apply_style()
	_retry_button.pressed.connect(_on_retry_pressed)
	_run_button.pressed.connect(_on_run_pressed)


## ponytail: la pantalla usaba D2StyleBox y D2Palette: marco dorado,
## texto hueso, botones de madera. Sobre la pantalla de combate ya
## neón eso se leia como otra aplicacion pegada encima. Ahora comparte
## paleta con el combate.
func _apply_style() -> void:
	_panel.add_theme_stylebox_override("panel", CyberStyleBox.panel(CyberStyleBox.RED))
	_dim.color = Color(0, 0, 0, 0.82)

	# Reintentar es la accion del JUGADOR: cyan, igual que ATTACK.
	_retry_button.add_theme_stylebox_override("normal", CyberStyleBox.button(CyberStyleBox.CYAN))
	_retry_button.add_theme_stylebox_override("hover", CyberStyleBox.button_hover(CyberStyleBox.CYAN))
	_retry_button.add_theme_stylebox_override("pressed", CyberStyleBox.button_pressed(CyberStyleBox.CYAN))
	_retry_button.add_theme_stylebox_override("focus", CyberStyleBox.button_hover(CyberStyleBox.CYAN))
	_retry_button.add_theme_color_override("font_color", CyberStyleBox.CYAN)
	_retry_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_retry_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	# Huir es la misma accion que RUN en la pantalla de combate: amber.
	_run_button.add_theme_stylebox_override("normal", CyberStyleBox.button(CyberStyleBox.AMBER))
	_run_button.add_theme_stylebox_override("hover", CyberStyleBox.button_hover(CyberStyleBox.AMBER))
	_run_button.add_theme_stylebox_override("pressed", CyberStyleBox.button_pressed(CyberStyleBox.AMBER))
	_run_button.add_theme_stylebox_override("focus", CyberStyleBox.button_hover(CyberStyleBox.AMBER))
	_run_button.add_theme_color_override("font_color", CyberStyleBox.AMBER)
	_run_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_run_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	_title.add_theme_color_override("font_color", CyberStyleBox.RED)
	_subtitle.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)


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
