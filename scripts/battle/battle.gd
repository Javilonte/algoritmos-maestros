extends CanvasLayer
class_name Battle

enum BattlePhase { IDLE, EDITING, COMPILING, EXECUTING, RESOLVING, ENEMY_TURN, FINISHED }

@onready var action_menu: Control = $BattleArena/ActionMenu
@onready var attack_button: Button = $BattleArena/ActionMenu/AttackButton
@onready var run_button: Button = $BattleArena/ActionMenu/RunButton
@onready var enemy_sprite: Sprite2D = $BattleArena/EnemySide/EnemySprite
@onready var player_sprite: Sprite2D = $BattleArena/PlayerSide/PlayerSprite
@onready var enemy_name_label: Label = $BattleArena/EnemySide/EnemyInfoPanel/EnemyName
@onready var enemy_hp_bar: HPBar = $BattleArena/EnemySide/EnemyInfoPanel/HPBar
@onready var player_name_label: Label = $BattleArena/PlayerSide/PlayerInfoPanel/PlayerName
@onready var player_hp_bar: HPBar = $BattleArena/PlayerSide/PlayerInfoPanel/HPBar
@onready var message_label: Label = $BattleArena/MessagePanel/MessageLabel
@onready var battle_terminal: BattleTerminal = $BattleTerminal
@onready var battle_timer_label: Label = $BattleArena/BattleTimer
@onready var battle_timer_bar: ColorRect = $BattleArena/BattleTimerBar
@onready var combo_label: Label = $BattleArena/ComboLabel
@onready var damage_layer: Node2D = $BattleArena/DamageLayer
@onready var battle_arena: Control = $BattleArena

const ENEMY_AUTO_DAMAGE: int = 12
const SHAKE_DURATION: float = 0.35
const SCREEN_SHAKE_INTENSITY := Vector2(8, 6)

var _enemy_data: Dictionary = {}
var _phase: BattlePhase = BattlePhase.IDLE
var _is_animating: bool = false
var _turn_start_ms: int = 0
var _challenge: ChallengeResource = null
var _arena_original_pos: Vector2 = Vector2.ZERO
var _active_shake_tween: Tween = null
var _active_chain: int = 0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena_original_pos = battle_arena.position
	EventBus.battle_requested.connect(_on_battle_requested)
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.code_executed.connect(_on_code_executed)
	EventBus.battle_timer_expired.connect(_on_battle_timer_expired)
	EventBus.combo_changed.connect(_on_combo_changed)
	attack_button.pressed.connect(_on_attack_pressed)
	run_button.pressed.connect(_on_run_pressed)
	battle_terminal.back_pressed.connect(_on_battle_terminal_back)

func _process(_delta: float) -> void:
	if _phase != BattlePhase.EDITING:
		return
	var challenge_id := String(_challenge.id) if _challenge != null else ""
	if challenge_id.is_empty():
		return
	var time_limit_ms: int = _challenge.time_limit_ms
	var elapsed: int = Time.get_ticks_msec() - _turn_start_ms
	var remaining: int = max(0, time_limit_ms - elapsed)
	battle_timer_label.text = "%d" % int(ceil(remaining / 1000.0))
	var ratio: float = float(remaining) / float(time_limit_ms)
	battle_timer_bar.scale.x = ratio
	battle_timer_bar.color = Color(0.4, 0.9, 0.4) if ratio > 0.4 else (Color(0.9, 0.7, 0.3) if ratio > 0.15 else Color(0.9, 0.3, 0.3))
	EventBus.battle_timer_tick.emit(remaining)
	if remaining <= 0 and not _is_animating:
		EventBus.battle_timer_expired.emit()

func _on_battle_requested(enemy_data: Dictionary) -> void:
	_kill_active_shake()
	_active_chain = 0
	_is_animating = false
	_turn_start_ms = 0
	battle_arena.position = _arena_original_pos
	_enemy_data = enemy_data
	GameManager.start_battle(enemy_data)
	var challenge_id := String(enemy_data.get("challenge_id", ""))
	_challenge = ChallengeRegistry.get_by_id(challenge_id)
	if _challenge == null:
		push_error("Battle: unknown challenge '%s'" % challenge_id)
		return
	battle_terminal.close()
	visible = true
	action_menu.visible = true
	get_tree().paused = true
	var display_name: String = String(enemy_data.get("display_name", "Unknown"))
	enemy_name_label.text = display_name
	player_name_label.text = "Player"
	_update_hp_bars()
	_set_message("A wild %s appeared!" % display_name)
	battle_timer_label.visible = false
	battle_timer_bar.visible = false
	battle_timer_bar.scale.x = 1.0
	battle_timer_bar.color = Color(0.4, 0.9, 0.4)
	combo_label.visible = false
	EventBus.battle_started.emit(enemy_data)
	_active_chain += 1
	var chain_id: int = _active_chain
	_phase = BattlePhase.IDLE
	await get_tree().create_timer(0.8, true).timeout
	if chain_id != _active_chain or _phase == BattlePhase.FINISHED:
		return
	_start_player_turn()

func _start_player_turn() -> void:
	_phase = BattlePhase.EDITING
	_turn_start_ms = Time.get_ticks_msec()
	_is_animating = false
	action_menu.visible = true
	battle_timer_label.visible = true
	battle_timer_bar.visible = true
	battle_timer_bar.scale.x = 1.0
	battle_timer_bar.color = Color(0.4, 0.9, 0.4)
	_set_message("Your turn — choose an action.")

func _on_attack_pressed() -> void:
	if _phase != BattlePhase.EDITING:
		return
	_is_animating = false
	action_menu.visible = false
	battle_terminal.open_for(String(_challenge.id))

func _on_run_pressed() -> void:
	if _is_animating:
		return
	_end_battle("run")

func _on_battle_terminal_back() -> void:
	if _phase == BattlePhase.EDITING:
		action_menu.visible = true

func _on_code_executed(result) -> void:
	if _is_animating:
		return
	if _phase == BattlePhase.FINISHED or _phase == BattlePhase.IDLE:
		return
	_is_animating = true
	battle_timer_label.visible = false
	battle_timer_bar.visible = false
	_phase = BattlePhase.EXECUTING
	_active_chain += 1
	var chain_id: int = _active_chain
	var elapsed: int = Time.get_ticks_msec() - _turn_start_ms
	var combo: int = GameManager.get_combo_count()
	var roll: DamageRoll = ScoringEngine.calculate_damage(result, _challenge, elapsed, combo)
	EventBus.damage_calculated.emit(roll)
	await get_tree().create_timer(0.2, true).timeout
	if chain_id != _active_chain or _phase == BattlePhase.FINISHED:
		return
	await _apply_player_roll(roll, chain_id)
	if chain_id != _active_chain or _phase == BattlePhase.FINISHED:
		return
	_phase = BattlePhase.ENEMY_TURN
	await _enemy_turn(chain_id)
	if chain_id != _active_chain or _phase == BattlePhase.FINISHED:
		return
	_start_player_turn()
	if chain_id == _active_chain:
		_is_animating = false

func _apply_player_roll(roll: DamageRoll, chain_id: int) -> void:
	if roll.amount > 0:
		GameManager.apply_damage("enemy", roll.amount)
		GameManager.increment_combo()
		_set_message("Code compiled! [color=#%s]%d dmg [TIER %s][/color]" % [_color_hex(roll.quality_tier), roll.amount, roll.quality_tier])
		DamageNumber.spawn(damage_layer, enemy_sprite.global_position + Vector2(0, -40), roll)
		if roll.quality_tier == "S" or roll.is_crit:
			_screen_shake(roll.is_crit)
		await get_tree().create_timer(0.6, true).timeout
		if chain_id != _active_chain:
			return
		if GameManager.get_hp("enemy") <= 0:
			_end_battle("win")
			return
	else:
		GameManager.reset_combo()
		_set_message("[color=#ff6666]Compile failed. Enemy takes advantage![/color]")
		DamageNumber.spawn(damage_layer, player_sprite.global_position + Vector2(0, -40), roll)
		await get_tree().create_timer(0.5, true).timeout

func _on_battle_timer_expired() -> void:
	if _phase != BattlePhase.EDITING or _is_animating:
		return
	_is_animating = true
	battle_timer_label.visible = false
	battle_timer_bar.visible = false
	_set_message("[color=#ffaa00]Time's up! Enemy strikes![/color]")
	GameManager.reset_combo()
	_phase = BattlePhase.ENEMY_TURN
	_active_chain += 1
	var chain_id: int = _active_chain
	await get_tree().create_timer(0.5, true).timeout
	if chain_id != _active_chain or _phase == BattlePhase.FINISHED:
		return
	await _enemy_turn(chain_id)
	if chain_id != _active_chain or _phase == BattlePhase.FINISHED:
		return
	_start_player_turn()
	if chain_id == _active_chain:
		_is_animating = false

func _enemy_turn(_chain_id: int) -> void:
	_set_message("%s counter-attacks!" % String(_enemy_data.get("display_name", "Enemy")))
	var damage: int = ENEMY_AUTO_DAMAGE
	GameManager.apply_damage("player", damage)
	var enemy_roll := DamageRoll.new()
	enemy_roll.amount = damage
	enemy_roll.quality_tier = "X"
	enemy_roll.source_side = "enemy"
	DamageNumber.spawn(damage_layer, player_sprite.global_position + Vector2(0, -40), enemy_roll)
	_screen_shake(false)
	if GameManager.get_hp("player") <= 0:
		_end_battle("lose")
		return
	await get_tree().create_timer(1.0, true).timeout

func _end_battle(result: String) -> void:
	if _phase == BattlePhase.FINISHED:
		return
	_phase = BattlePhase.FINISHED
	_kill_active_shake()
	if result == "win" and _enemy_data.has("node"):
		var enemy_node: Variant = _enemy_data["node"]
		if enemy_node is Enemy:
			(enemy_node as Enemy).defeat()
	visible = false
	battle_terminal.close()
	action_menu.visible = true
	battle_timer_label.visible = false
	battle_timer_bar.visible = false
	combo_label.visible = false
	battle_arena.position = _arena_original_pos
	GameManager.reset_battle_state()
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	get_tree().paused = false
	_is_animating = false
	EventBus.battle_ended.emit(result)

func _on_hp_changed(side: String, current: int, max_hp: int) -> void:
	var bar: HPBar = enemy_hp_bar if side == "enemy" else player_hp_bar
	bar.set_hp(current, max_hp)

func _update_hp_bars() -> void:
	enemy_hp_bar.set_hp(GameManager.enemy_hp, GameManager.enemy_max_hp)
	player_hp_bar.set_hp(GameManager.player_hp, GameManager.player_max_hp)

func _set_message(text: String) -> void:
	message_label.text = text

func _on_combo_changed(combo: int, multiplier: float) -> void:
	if combo <= 0:
		combo_label.visible = false
		return
	combo_label.visible = true
	combo_label.text = "COMBO x%.1f" % multiplier
	combo_label.add_theme_color_override("font_color", Color(0.4 + min(combo, 5) * 0.1, 0.9, 0.5))
	combo_label.scale = Vector2(1.3, 1.3) if combo > 1 else Vector2.ONE
	var t := combo_label.create_tween()
	t.tween_property(combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _screen_shake(hard: bool) -> void:
	_kill_active_shake()
	var intensity: Vector2 = SCREEN_SHAKE_INTENSITY * (1.5 if hard else 1.0)
	var tween: Tween = battle_arena.create_tween()
	var steps: int = 6
	for i in steps:
		var shake_offset := Vector2(
			randf_range(-intensity.x, intensity.x),
			randf_range(-intensity.y, intensity.y)
		)
		var t: float = SHAKE_DURATION / float(steps)
		tween.tween_property(battle_arena, "position", _arena_original_pos + shake_offset, t)
	tween.tween_property(battle_arena, "position", _arena_original_pos, 0.05)
	_active_shake_tween = tween

func _kill_active_shake() -> void:
	if _active_shake_tween != null and _active_shake_tween.is_valid():
		_active_shake_tween.kill()
	_active_shake_tween = null
	battle_arena.position = _arena_original_pos

func _color_hex(tier: String) -> String:
	match tier:
		"S": return "ff66ff"
		"A": return "66ffdd"
		"B": return "66ff66"
		"C": return "cccc66"
		"D": return "999999"
		"X": return "ff6666"
	return "ffffff"
