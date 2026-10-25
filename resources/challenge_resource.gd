class_name ChallengeResource extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var difficulty: int = 1
@export var prompt: String = ""
@export var starter_code: String = ""
@export var function_signature: String = ""
@export var function_name_hint: String = ""
@export var test_cases: Array[TestCase] = []
@export var time_limit_ms: int = 30000
@export var base_damage: int = 20
@export var perfect_damage: int = 80
@export var tags: PackedStringArray = PackedStringArray()
## El skill que esta pelea practica. La pelea lo nombra (en el retrato del
## enemigo y en el contrato del editor) para que el jugador sepa QUE esta
## aprendiendo, no solo que tiene que escribir.
@export var skill_id: StringName = &""
@export var runner_path: String = ""

# AST validation knobs (Phase 2 pipeline). Defaults are tolerant so existing
# challenges keep working without re-authoring.
@export var ast_min_statements: int = 1
@export var ast_required_features: PackedStringArray = PackedStringArray()
@export var ast_return_substring: String = ""
@export var validation_mode: String = "ast_oracle"
