extends CanvasLayer
class_name Battle

@onready var action_menu: Control = $BattleArena/ActionMenu
@onready var attack_button: Button = $BattleArena/ActionMenu/AttackButton
@onready var run_button: Button = $BattleArena/ActionMenu/RunButton
@onready var enemy_sprite: Sprite2D = $BattleArena/EnemySide/EnemySprite
@onready var player_sprite: Sprite2D = $BattleArena/PlayerSide/PlayerSprite
@onready var enemy_name_label: Label = $BattleArena/EnemySide/EnemyInfoPanel/EnemyName
@onready var enemy_hp_bar: HPBar = $BattleArena/EnemySide/EnemyInfoPanel/HPBar
@onready var player_name_label: Label = $BattleArena/PlayerSide/PlayerInfoPanel/PlayerName
@onready var player_hp_bar: HPBar = $BattleArena/PlayerSide/PlayerInfoPanel/HPBar
@onready var message_label: Label = $BattleArena/MessageLabel
@onready var battle_terminal: BattleTerminal = $BattleTerminal

const PLAYER_DAMAGE: int = 25
const ENEMY_DAMAGE: int = 10

var _enemy_data: Dictionary = {}
var _is_animating: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.battle_requested.connect(_on_battle_requested)
	EventBus.hp_changed.connect(_on_hp_changed)
	attack_button.pressed.connect(_on_attack_pressed)
	run_button.pressed.connect(_on_run_pressed)
	battle_terminal.submitted.connect(_on_battle_terminal_submitted)
	battle_terminal.back_pressed.connect(_on_battle_terminal_back)

func _on_battle_requested(enemy_data: Dictionary) -> void:
	_enemy_data = enemy_data
	GameManager.start_battle(enemy_data)
	visible = true
	get_tree().paused = true
	enemy_name_label.text = enemy_data.display_name
	player_name_label.text = "Player"
	_update_hp_bars()
	_set_message("A wild %s appeared!" % enemy_data.display_name)
	action_menu.visible = true
	battle_terminal.close()
	EventBus.battle_started.emit(enemy_data)

func _on_attack_pressed() -> void:
	if _is_animating:
		return
	action_menu.visible = false
	battle_terminal.open_for(_enemy_data.challenge_id)

func _on_run_pressed() -> void:
	if _is_animating:
		return
	_end_battle("run")

func _on_battle_terminal_back() -> void:
	action_menu.visible = true

func _on_battle_terminal_submitted(success: bool) -> void:
	_is_animating = true
	if success:
		GameManager.apply_damage("enemy", PLAYER_DAMAGE)
		if GameManager.enemy_hp <= 0:
			_set_message("%s fainted!" % _enemy_data.display_name)
			await get_tree().create_timer(1.0).timeout
			_end_battle("win")
			_is_animating = false
			return
		await _enemy_turn()
	else:
		GameManager.apply_damage("player", ENEMY_DAMAGE)
		if GameManager.player_hp <= 0:
			_set_message("You fainted!")
			await get_tree().create_timer(1.0).timeout
			_end_battle("lose")
			_is_animating = false
			return
		await _enemy_turn()
	_is_animating = false

func _enemy_turn() -> void:
	_set_message("%s counter-attacks!" % _enemy_data.display_name)
	await get_tree().create_timer(1.0).timeout
	battle_terminal.close()
	action_menu.visible = true
	_set_message("Your turn — choose an action.")

func _end_battle(result: String) -> void:
	if result == "win" and _enemy_data.has("node") and _enemy_data["node"] != null:
		(_enemy_data["node"] as Enemy).defeat()
	visible = false
	battle_terminal.close()
	action_menu.visible = true
	GameManager.reset_battle_state()
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	get_tree().paused = false
	EventBus.battle_ended.emit(result)

func _on_hp_changed(side: String, current: int, max_hp: int) -> void:
	var bar: HPBar = enemy_hp_bar if side == "enemy" else player_hp_bar
	bar.set_hp(current, max_hp)

func _update_hp_bars() -> void:
	enemy_hp_bar.set_hp(GameManager.enemy_hp, GameManager.enemy_max_hp)
	player_hp_bar.set_hp(GameManager.player_hp, GameManager.player_max_hp)

func _set_message(text: String) -> void:
	message_label.text = text
