extends Resource
class_name SkillNode

## Nodo individual del skill tree.
## Repr un "punto de conocimiento" que el jugador desbloquea.

enum Category { CONTROL_FLOW, POINTERS, STL, TEMPLATES, CONCURRENCY, RECURSION }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.CONTROL_FLOW
@export var required_level: int = 1
@export var cost_xp: int = 100
@export var keywords: PackedStringArray = PackedStringArray()  # ej ["if", "else"]
@export var macros_unlocked: PackedStringArray = PackedStringArray()
@export var enemies_unlocked: PackedStringArray = PackedStringArray()
@export var depends_on: PackedStringArray = PackedStringArray()  # ids padres
@export var icon_color: Color = Color(0.5, 0.5, 0.9)

var unlocked: bool = false