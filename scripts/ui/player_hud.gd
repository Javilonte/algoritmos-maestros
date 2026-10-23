extends CanvasLayer
class_name PlayerHUD

## HUD estilo Diablo II: sigil de nivel + barra HP + barra XP.
## Se oculta automaticamente cuando el juego no esta en estado OVERWORLD
## (batalla, dialogo, terminal, menu) para evitar superposicion.

const STATE_CHECK_INTERVAL := 0.2

@onready var level_sigil: Panel = $Margin/HBox/LevelSigil
@onready var level_label: Label = $Margin/HBox/LevelSigil/LevelLabel
@onready var hp_label: Label = $Margin/HBox/HPBlock/HPLabel
@onready var hp_bar: ProgressBar = $Margin/HBox/HPBlock/HPBar
@onready var xp_label: Label = $Margin/HBox/XPBlock/XPLabel
@onready var xp_bar: ProgressBar = $Margin/HBox/XPBlock/XPBar

var _state_check_acc := 0.0

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_local_overrides()
	EventBus.hp_changed.connect(_on_hp_changed)
	var st := get_node_or_null("/root/SkillTree") as SkillTreeData
	if st:
		st.xp_changed.connect(_on_xp_changed)
		st.level_changed.connect(_on_level_changed)
	_refresh()
	_update_visibility()

func _process(delta: float) -> void:
	_state_check_acc += delta
	if _state_check_acc >= STATE_CHECK_INTERVAL:
		_state_check_acc = 0.0
		_update_visibility()

func _update_visibility() -> void:
	visible = GameManager.is_state(GameManager.GameState.OVERWORLD)

func _apply_local_overrides() -> void:
	level_sigil.add_theme_stylebox_override("panel", D2StyleBox.sigil_small())
	level_label.add_theme_color_override("font_color", D2Palette.GOLD_TEXT_BRIGHT)
	level_label.add_theme_font_size_override("font_size", 18)

	hp_label.add_theme_color_override("font_color", D2Palette.BONE_TEXT)
	hp_label.add_theme_font_size_override("font_size", UIMetrics.FONT_LABEL)

	hp_bar.add_theme_stylebox_override("background", D2StyleBox.bar_bg())
	hp_bar.add_theme_stylebox_override("fill", D2StyleBox.bar_fill(D2Palette.HP_RED_HI))

	xp_label.add_theme_color_override("font_color", D2Palette.XP_BLUE_HI)
	xp_label.add_theme_font_size_override("font_size", UIMetrics.FONT_LABEL - 1)

	xp_bar.add_theme_stylebox_override("background", D2StyleBox.bar_bg())
	xp_bar.add_theme_stylebox_override("fill", D2StyleBox.bar_fill(D2Palette.XP_BLUE))

func _on_hp_changed(side: String, current: int, max_hp: int) -> void:
	if side != "player":
		return
	hp_bar.max_value = max_hp
	hp_bar.value = clamp(current, 0, max_hp)
	hp_label.text = "%d / %d" % [current, max_hp]

func _on_xp_changed(current_xp: int, to_next: int) -> void:
	xp_bar.max_value = max(to_next, 1)
	xp_bar.value = clamp(current_xp, 0, to_next)
	xp_label.text = "%d / %d" % [current_xp, to_next]

func _on_level_changed(level: int) -> void:
	level_label.text = "%d" % level

func _refresh() -> void:
	hp_bar.max_value = GameManager.player_max_hp
	hp_bar.value = GameManager.player_hp
	hp_label.text = "%d / %d" % [GameManager.player_hp, GameManager.player_max_hp]
	var st := get_node_or_null("/root/SkillTree") as SkillTreeData
	if st:
		_on_xp_changed(st.current_xp, st._xp_for_next_level())
		_on_level_changed(st.current_level)