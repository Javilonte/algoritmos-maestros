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
@onready var message_label: Label = $BattleArena/MessagePanel/MessageLabel
@onready var message_panel: Panel = $BattleArena/MessagePanel
@onready var enemy_sigil: Panel = $BattleArena/EnemySide/EnemySigil
@onready var player_sigil: Panel = $BattleArena/PlayerSide/PlayerSigil
@onready var battle_terminal: BattleTerminal = $BattleTerminal

var controller: CombatController
var vfx: VFXController
var audio: AudioManager

var _enemy_data: Dictionary = {}
var _is_animating: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_local_overrides()
	# Construir subsistemas locales (pueden venir ya como hijos si se prefiere).
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	controller = CombatController.new()
	controller.name = "CombatController"
	controller.terminal = battle_terminal
	add_child(controller)
	# VFX: usa el nodo hijo VFXController si existe en escena, si no lo crea.
	vfx = get_node_or_null("VFXController") as VFXController
	if vfx == null:
		vfx = VFXController.new()
		vfx.name = "VFXController"
		add_child(vfx)
	var key_player := AudioStreamPlayer.new()
	key_player.name = "KeyClackPlayer"
	key_player.stream = audio.get_key_clack()
	key_player.bus = AudioManager.BUS_SFX
	add_child(key_player)
	vfx.key_clack_path = NodePath("../KeyClackPlayer")
	vfx.bind_to_controller(controller)
	vfx.bind_to_terminal(battle_terminal)
	# Conectar con la batalla legacy (HP bars + mensajes).
	EventBus.battle_requested.connect(_on_battle_requested)
	EventBus.hp_changed.connect(_on_hp_changed)
	attack_button.pressed.connect(_on_attack_pressed)
	run_button.pressed.connect(_on_run_pressed)
	battle_terminal.back_pressed.connect(_on_battle_terminal_back)
	battle_terminal.macro_used.connect(_on_macro_used)
	# Conexiones del controller para HP/damage/feedback.
	controller.damage_applied.connect(_on_damage_applied)
	controller.compilation_completed.connect(_on_compilation_completed)
	controller.round_ended.connect(_on_round_ended)
	# Refrescar macros disponibles según skill tree.
	var st := get_node_or_null("/root/SkillTree") as SkillTreeData
	if st:
		_refresh_macros_from_skill_tree(st)
		st.skill_unlocked.connect(func(_id): _refresh_macros_from_skill_tree(st))

func _refresh_macros_from_skill_tree(st: SkillTreeData) -> void:
	if st == null:
		return
	var allowed := st.get_unlocked_macros()
	var filtered: Array[String] = []
	for m in battle_terminal.macros:
		if m in allowed:
			filtered.append(m)
	battle_terminal.macro_snippets = _filter_dict(battle_terminal.macro_snippets, allowed)
	battle_terminal.macros = filtered
	battle_terminal._refresh_macro_bar()

func _filter_dict(src: Dictionary, allowed: PackedStringArray) -> Dictionary:
	var out := {}
	for k in src:
		if k in allowed:
			out[k] = src[k]
	return out

func _on_battle_requested(enemy_data: Dictionary) -> void:
	_enemy_data = enemy_data
	GameManager.start_battle(enemy_data)
	visible = true
	GameManager.pause_game()
	var display_name: String = String(enemy_data.get("display_name", "Unknown"))
	enemy_name_label.text = display_name
	player_name_label.text = "Player"
	if enemy_data.has("color"):
		enemy_sprite.modulate = enemy_data.color
	_update_hp_bars()
	_set_message("A wild %s appeared!" % display_name)
	action_menu.visible = true
	battle_terminal.close()
	# Inicia el round en el controller para que gestione timer + HTTP.
	controller.start_round(enemy_data)
	EventBus.battle_started.emit(enemy_data)

func _on_attack_pressed() -> void:
	if _is_animating:
		return
	action_menu.visible = false
	battle_terminal.open_for(String(_enemy_data.get("challenge_id", "main_exit_check")))

func _on_run_pressed() -> void:
	if _is_animating:
		return
	_end_battle("run")

func _on_battle_terminal_back() -> void:
	action_menu.visible = true

func _on_macro_used(macro_name: String) -> void:
	_set_message("Macro '%s' inserted" % macro_name)

func _on_compilation_completed(result: Dictionary) -> void:
	if result.get("compiled", false):
		var msg := "Compiled OK"
		if result.get("offline", false):
			msg += " (offline mode, x0.5 dmg)"
		_append_console("[color=green]>> %s[/color]" % msg)
		_play_sfx(true)
	else:
		var err := String(result.get("compile_message", result.get("stderr", "compile error")))
		_append_console("[color=red]>> %s[/color]" % err)
		_play_sfx(false)

func _on_damage_applied(amount: int, _hp_after: int, breakdown: Dictionary) -> void:
	# Aplica al GameManager (que ya emite hp_changed).
	GameManager.apply_damage("enemy", amount)
	var crit := bool(breakdown.get("crit", false))
	var element := String(breakdown.get("element", "?"))
	if crit:
		_set_message("CRITICAL HIT! %d dmg (%s)" % [amount, element])
	else:
		_set_message("%d dmg (%s)" % [amount, element])

func _on_round_ended(victory: bool) -> void:
	_is_animating = true
	if victory:
		var xp_reward := int(_enemy_data.get("xp_reward", 50))
		_set_message("%s fainted! +%d XP" % [String(_enemy_data.get("display_name", "Enemy")), xp_reward])
		SkillTree.add_xp(xp_reward)
		if _enemy_data.has("node"):
			var node: Variant = _enemy_data["node"]
			if node is Enemy:
				(node as Enemy).defeat()
		await get_tree().create_timer(1.0).timeout
		_end_battle("win")
	else:
		await _enemy_turn()

func _enemy_turn() -> void:
	_set_message("%s counter-attacks!" % String(_enemy_data.get("display_name", "Enemy")))
	GameManager.apply_damage("player", GameConstants.ENEMY_ATTACK_DAMAGE)
	if GameManager.player_hp <= 0:
		_set_message("You fainted!")
		await get_tree().create_timer(1.0).timeout
		_end_battle("lose")
		return
	await get_tree().create_timer(1.0).timeout
	battle_terminal.reset_for_next_round()
	action_menu.visible = true
	_set_message("Your turn — choose an action.")
	_is_animating = false

func _end_battle(result: String) -> void:
	controller.cancel_round()
	visible = false
	battle_terminal.close()
	action_menu.visible = true
	GameManager.reset_battle_state()
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	GameManager.unpause_game()
	EventBus.battle_ended.emit(result)
	_is_animating = false

func _on_hp_changed(side: String, current: int, max_hp: int) -> void:
	var bar: HPBar = enemy_hp_bar if side == "enemy" else player_hp_bar
	bar.set_hp(current, max_hp)

func _update_hp_bars() -> void:
	enemy_hp_bar.set_hp(GameManager.enemy_hp, GameManager.enemy_max_hp)
	player_hp_bar.set_hp(GameManager.player_hp, GameManager.player_max_hp)

func _set_message(text: String) -> void:
	message_label.text = text

func _apply_local_overrides() -> void:
	# Sigils: estilo sigil (marco cuadrado bronce sobre fondo oscuro).
	if enemy_sigil:
		enemy_sigil.add_theme_stylebox_override("panel", D2StyleBox.sigil())
	if player_sigil:
		player_sigil.add_theme_stylebox_override("panel", D2StyleBox.sigil())
	# Message panel: panel bronce para el cartel de batalla.
	if message_panel:
		message_panel.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())

func _append_console(text: String) -> void:
	battle_terminal.console_output.append_text(text + "\n")

func _play_sfx(success: bool) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = audio.get_hit(success)
	p.bus = AudioManager.BUS_SFX
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
