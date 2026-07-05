extends Node

enum GameState { BOOT, MAIN_MENU, OVERWORLD, TERMINAL, BATTLE, DIALOGUE }

const PLAYER_MAX_HP: int = GameConstants.PLAYER_MAX_HP

var current_state: GameState = GameState.BOOT
var current_challenge_id: String = ""

var player_max_hp: int = PLAYER_MAX_HP
var player_hp: int = PLAYER_MAX_HP
var enemy_max_hp: int = 0
var enemy_hp: int = 0
var current_enemy_data: Dictionary = {}

## Cambia el estado del juego. No hace nada si el estado ya es el mismo.
func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	current_state = new_state

func _ready() -> void:
	EventBus.skill_unlocked.connect(_on_skill_unlocked)
	EventBus.battle_ended.connect(_on_battle_ended)
	get_tree().set_auto_accept_quit(false)
	get_tree().root.close_requested.connect(_on_app_close_requested)

func _on_skill_unlocked(_skill_id: StringName) -> void:
	SaveManager.save_game(get_save_data())

func _on_battle_ended(_result: String) -> void:
	SaveManager.save_game(get_save_data())

func _on_app_close_requested() -> void:
	SaveManager.save_game(get_save_data())
	get_tree().quit()

## Retorna true si el estado actual coincide con el dado.
func is_state(state: GameState) -> bool:
	return current_state == state

## Retorna true solo cuando el jugador puede moverse libremente.
func is_player_input_allowed() -> bool:
	return current_state == GameState.OVERWORLD

func set_challenge(challenge_id: String) -> void:
	current_challenge_id = challenge_id

func clear_challenge() -> void:
	current_challenge_id = ""

## Pausa el árbol de escena completo.
func pause_game() -> void:
	get_tree().paused = true

## Reanuda el árbol de escena completo.
func unpause_game() -> void:
	get_tree().paused = false

## Retorna true si el árbol está pausado.
func is_paused() -> bool:
	return get_tree().paused

## Inicializa una batalla con los datos del enemigo.
func start_battle(enemy_data: Dictionary) -> void:
	current_enemy_data = enemy_data
	enemy_max_hp = int(enemy_data.get("max_hp", 100))
	enemy_hp = enemy_max_hp
	player_hp = player_max_hp
	current_state = GameState.BATTLE
	EventBus.hp_changed.emit("player", player_hp, player_max_hp)
	EventBus.hp_changed.emit("enemy", enemy_hp, enemy_max_hp)

## Aplica daño a un lado del combate ("player" o "enemy").
func apply_damage(side: String, amount: int) -> void:
	if side == "enemy":
		enemy_hp = max(0, enemy_hp - amount)
		EventBus.hp_changed.emit("enemy", enemy_hp, enemy_max_hp)
	elif side == "player":
		player_hp = max(0, player_hp - amount)
		EventBus.hp_changed.emit("player", player_hp, player_max_hp)

## Resetea el estado de batalla sin cambiar el GameState.
func reset_battle_state() -> void:
	player_hp = player_max_hp
	enemy_hp = 0
	enemy_max_hp = 0
	current_enemy_data = {}

## Resetea todo el estado para un juego nuevo.
func reset_to_new_game() -> void:
	player_hp = PLAYER_MAX_HP
	player_max_hp = PLAYER_MAX_HP
	enemy_hp = 0
	enemy_max_hp = 0
	current_enemy_data = {}
	current_challenge_id = ""
	current_state = GameState.BOOT

## Retorna un diccionario con los datos para guardar.
func get_save_data() -> Dictionary:
	var skill_tree_data: Dictionary = {}
	var st := get_node_or_null("/root/SkillTree")
	if st and st.has_method("save_state"):
		skill_tree_data = st.save_state()
	return {
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"skill_tree": skill_tree_data,
		"save_version": 1,
	}

## Aplica datos cargados de un save (backward-compatible con saves viejos).
func apply_save_data(data: Dictionary) -> void:
	player_hp = int(data.get("player_hp", PLAYER_MAX_HP))
	player_max_hp = int(data.get("player_max_hp", PLAYER_MAX_HP))
	# SkillTree: si el save no tiene 'skill_tree', no inicializamos (defaults del autoload).
	if data.has("skill_tree"):
		var st := get_node_or_null("/root/SkillTree")
		if st and st.has_method("load_state"):
			var raw: Variant = data["skill_tree"]
			if raw is Dictionary:
				st.load_state(raw)
