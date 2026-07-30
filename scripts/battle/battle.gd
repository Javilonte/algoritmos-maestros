extends CanvasLayer
class_name Battle

enum BattlePhase { IDLE, EDITING, COMPILING, EXECUTING, RESOLVING, ENEMY_TURN, FINISHED }

@onready var action_menu: Control = $BattleArena/ActionMenu
@onready var attack_button: Button = $BattleArena/ActionMenu/AttackButton
@onready var run_button: Button = $BattleArena/ActionMenu/RunButton
@onready var enemy_portrait: BattlePortrait = $BattleArena/PortraitsRow/EnemyPortrait
@onready var player_portrait: BattlePortrait = $BattleArena/PortraitsRow/PlayerPortrait
@onready var message_label: RichTextLabel = $BattleArena/MessagePanel/MessageLabel
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
	enemy_portrait.set_identity(display_name, int(enemy_data.get("level", 1)))
	player_portrait.set_identity("Player", 1)
	_update_hp_bars()
	_set_message("A wild %s appeared!" % display_name)
	battle_timer_label.visible = false
	battle_timer_bar.visible = false
	battle_timer_bar.scale.x = 1.0
	battle_timer_bar.color = Color(0.4, 0.9, 0.4)
	combo_label.visible = false
	# ponytail: show a dramatic banner for boss encounters. EnemyData.is_boss
	# is declared in iso_meta.gd but was unused — this is the first consumer.
	if bool(enemy_data.get("is_boss", false)):
		_show_battle_banner("BOSS ENCOUNTER", display_name)
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
	# ponytail: split this loop into 3 small methods so each phase
	# (compile success / fail / enemy turn) is testable in isolation and
	# the chain-id guards live in one helper.
	await get_tree().create_timer(0.2, true).timeout
	if not _is_chain_alive(chain_id):
		return
	if roll.amount > 0:
		await _on_compile_success(roll, chain_id)
	else:
		await _on_compile_fail(chain_id)
	if not _is_chain_alive(chain_id):
		return
	_phase = BattlePhase.ENEMY_TURN
	await _enemy_turn(chain_id)
	if not _is_chain_alive(chain_id):
		return
	_start_player_turn()
	if chain_id == _active_chain:
		_is_animating = false


## ponytail: extracted from _on_code_executed — chain-id check
## is repeated 4x in the original; one helper keeps it in sync.
func _is_chain_alive(chain_id: int) -> bool:
	return chain_id == _active_chain and _phase != BattlePhase.FINISHED


## ponytail: play a procedural SFX. The AudioManager is autoloaded
## so we can reach it without keeping a reference. Routed through
## the SFX bus which is volume-controlled by the options menu.
func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = AudioManager.BUS_SFX
	add_child(player)
	player.play()
	# ponytail: free the player when the stream ends so we don't leak
	# one-shot nodes across many battle turns.
	player.finished.connect(player.queue_free)


## ponytail: extracted from _on_code_executed — handles the
## "code compiled and dealt damage" path.
func _on_compile_success(roll: DamageRoll, chain_id: int) -> void:
	GameManager.apply_damage("enemy", roll.amount)
	GameManager.increment_combo()
	_set_message("Code compiled! [color=#%s]%d dmg [TIER %s][/color]" % [_color_hex(roll.quality_tier), roll.amount, roll.quality_tier])
	DamageNumber.spawn(damage_layer, enemy_portrait.global_position + Vector2(0, -120), roll)
	enemy_portrait.flash_hurt()
	_play_sfx(AudioManager.hit(true))
	if roll.quality_tier == "S" or roll.is_crit:
		_screen_shake(roll.is_crit)
	await get_tree().create_timer(0.6, true).timeout
	if not _is_chain_alive(chain_id):
		return
	if GameManager.get_hp("enemy") <= 0:
		_end_battle("win")
		return
	# ponytail: enemy counter-attack after a successful player turn.
	await _enemy_turn(chain_id)


## ponytail: extracted from _on_code_executed — handles the
## "compile failed" path. No damage to enemy, player gets punished.
func _on_compile_fail(chain_id: int) -> void:
	GameManager.reset_combo()
	_set_message("[color=#ff6666]Compile failed. Enemy takes advantage![/color]")
	var zero_roll := DamageRoll.new()
	zero_roll.amount = 0
	zero_roll.quality_tier = "X"
	zero_roll.source_side = "player"
	DamageNumber.spawn(damage_layer, player_portrait.global_position + Vector2(0, -120), zero_roll)
	player_portrait.flash_hurt()
	_play_sfx(AudioManager.hit(false))
	await get_tree().create_timer(0.5, true).timeout

func _on_battle_timer_expired() -> void:
	if _phase != BattlePhase.EDITING or _is_animating:
		return
	_is_animating = true
	battle_timer_label.visible = false
	battle_timer_bar.visible = false
	_set_message("[color=#ffaa00]Time's up! Enemy strikes![/color]")
	GameManager.reset_combo()
	_play_sfx(AudioManager.hit(false))
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
	DamageNumber.spawn(damage_layer, player_portrait.global_position + Vector2(0, -120), enemy_roll)
	player_portrait.flash_hurt()
	_play_sfx(AudioManager.hit(false))
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
	# ponytail: on lose, show the GameOver screen instead of silently
	# dumping the player back to overworld. The screen handles its own
	# retry/run flow and calls queue_free on dismissal.
	if result == "lose":
		_show_game_over()
		return
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
	# ponytail: wire the XP loop. EnemyData.xp_reward is declared in
	# iso_meta.gd:104-128 (50..400 by enemy) but the grant was missing —
	# so skill unlocks never fired from combat. Single line closes the loop.
	if result == "win":
		var xp_reward: int = int(_enemy_data.get("xp_reward", 0))
	# ponytail: wire the XP loop. EnemyData.xp_reward is declared in
	# iso_meta.gd:104-128 (50..400 by enemy) but the grant was missing —
	# so skill unlocks never fired from combat. Single line closes the loop.
	if result == "win":
		var xp_reward: int = int(_enemy_data.get("xp_reward", 0))
		if xp_reward > 0:
			SkillTree.add_xp(xp_reward)
	EventBus.battle_ended.emit(result)


## ponytail: spawn a transient BattleBanner as a child of the BattleArena.
## Used to surface boss encounters with a more dramatic frame.
func _show_battle_banner(title: String, subtitle: String) -> void:
	var banner_scene: PackedScene = load("res://scenes/battle/battle_banner.tscn") as PackedScene
	if banner_scene == null:
		return
	var banner: Node = banner_scene.instantiate()
	if banner == null:
		return
	battle_arena.add_child(banner)
	if banner.has_method("show_banner"):
		banner.show_banner(title, subtitle)


## ponytail: show the GameOver screen as a child of the BattleArena. The
## screen is responsible for its own retry/run flow and calls queue_free
## on dismissal. We DON'T unpause the tree — GameOver blocks input.
func _show_game_over() -> void:
	battle_terminal.close()
	action_menu.visible = false
	battle_timer_label.visible = false
	battle_timer_bar.visible = false
	combo_label.visible = false
	var go_scene: PackedScene = load("res://scenes/ui/game_over.tscn") as PackedScene
	if go_scene == null:
		# ponytail: fall back to silent end-of-battle if the scene is
		# missing — better to keep the game playable than to crash.
		visible = false
		GameManager.reset_battle_state()
		GameManager.change_state(GameManager.GameState.OVERWORLD)
		get_tree().paused = false
		EventBus.battle_ended.emit("lose")
		return
	var go: Node = go_scene.instantiate()
	if go == null:
		return
	# Setup metadata before adding to tree (so handlers are ready).
	if go.has_method("setup"):
		var enemy_name: String = String(_enemy_data.get("display_name", "Enemy"))
		var challenge_id: StringName = StringName(String(_enemy_data.get("challenge_id", "")))
		go.setup(challenge_id, enemy_name)
	battle_arena.add_child(go)
	if go.has_signal("retry_pressed"):
		go.retry_pressed.connect(_on_game_over_retry)
	if go.has_signal("run_pressed"):
		go.run_pressed.connect(_on_game_over_run)
	# Keep the tree paused so the player can't walk away mid-decision.


func _on_game_over_retry() -> void:
	# ponytail: re-open the BattleTerminal with the same challenge.
	# The player keeps their HP (no penalty), the enemy resets to max.
	visible = true
	_is_animating = false
	_phase = BattlePhase.EDITING
	_turn_start_ms = Time.get_ticks_msec()
	action_menu.visible = true
	battle_timer_label.visible = true
	battle_timer_bar.visible = true
	battle_timer_bar.scale.x = 1.0
	battle_timer_bar.color = Color(0.4, 0.9, 0.4)
	_update_hp_bars()
	# Re-load the challenge in case it was cleared.
	var challenge_id: String = String(_challenge.id) if _challenge != null else ""
	if not challenge_id.is_empty():
		battle_terminal.open_for(challenge_id)
	_set_message("Retry — choose an action.")


func _on_game_over_run() -> void:
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
	EventBus.battle_ended.emit("lose")

func _on_hp_changed(side: String, current: int, max_hp: int) -> void:
	if side == "enemy":
		enemy_portrait.set_hp(current, max_hp)
	else:
		player_portrait.set_hp(current, max_hp)


func _update_hp_bars() -> void:
	enemy_portrait.set_hp(GameManager.enemy_hp, GameManager.enemy_max_hp)
	player_portrait.set_hp(GameManager.player_hp, GameManager.player_max_hp)

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
