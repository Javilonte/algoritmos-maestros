class_name ChallengeData
extends Resource

## Contrato de un challenge para el sandbox.
## Define stdin/expected_output/limites/hints/puntaje base.
## Usado por SandboxClient para construir el request a Judge0
## y por BattleTerminal para mostrar el prompt y los hints.

@export var id: StringName = &""
@export var display_name: String = ""
@export var prompt: String = ""
@export var stdin: String = ""
@export var expected_output: String = ""
@export var time_limit_sec: float = 2.0
@export var memory_limit_kb: int = 128000
@export var base_score: int = 10
@export var keyword_bonus: Dictionary = {}
@export var hint_lines: PackedStringArray = PackedStringArray()