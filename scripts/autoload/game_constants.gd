class_name GameConstants

## Constantes globales del juego.
## Centraliza valores que antes estaban dispersos como magic numbers.

# Batalla
const PLAYER_ATTACK_DAMAGE: int = 25
const ENEMY_ATTACK_DAMAGE: int = 10
const PLAYER_MAX_HP: int = 100

# Enemigos
const DEFAULT_ENEMY_MAX_HP: int = 100
const DEFAULT_RESPAWN_TIME: float = 30.0

# UI
const TYPEWRITER_CHAR_DELAY: float = 0.04
const TYPEWRITER_LINE_DELAY: float = 0.3
const TYPEWRITER_FINAL_DELAY: float = 0.8
const CURSOR_BLINK_INTERVAL: float = 0.6

# CanvasLayers
const LAYER_BATTLE: int = 9
const LAYER_TERMINAL: int = 10
const LAYER_BATTLE_TERMINAL: int = 11
const LAYER_DIALOGUE: int = 12

# Dialogue Event Types
const EVENT_BATTLE: String = "battle"
const EVENT_SCENE_CHANGE: String = "scene_change"
const EVENT_ITEM: String = "item"
const EVENT_CUSTOM: String = "custom"

# Challenge IDs
const CHALLENGE_MAIN_EXIT: String = "main_exit_check"

# Timer de combate
const COMBAT_ROUND_DURATION: float = 30.0
const COMBAT_NETWORK_TIMEOUT: float = 6.0

# Sandbox (Judge0 RapidAPI)
const SANDBOX_BASE_URL: String = "https://judge0-ce.p.rapidapi.com"
const SANDBOX_LANGUAGE_CPP: int = 54

# Splash screen
const SPLASH_SAFETY_TIMEOUT: float = 30.0
const SPLASH_FADE_OUT_DURATION: float = 0.4
const SPLASH_NEXT_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
