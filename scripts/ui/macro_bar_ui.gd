extends HBoxContainer
class_name MacroBarUI

## UI que muestra las macros desbloqueadas.
## Se actualiza cuando el SkillTree (autoload /root/SkillTree) emite skill_unlocked.

var _buttons: Dictionary = {}
var _tree: SkillTreeData

func _ready() -> void:
	_tree = get_node_or_null("/root/SkillTree") as SkillTreeData
	if _tree:
		_tree.skill_unlocked.connect(_on_skill_unlocked)
		_refresh()

func _on_skill_unlocked(_skill_id: StringName) -> void:
	_refresh()

func _refresh() -> void:
	if _tree == null:
		return
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	var macros := _tree.get_unlocked_macros()
	for i in range(macros.size()):
		var macro_name: String = macros[i]
		var btn := Button.new()
		btn.text = "Alt+%d %s" % [i + 1, macro_name]
		btn.custom_minimum_size = Vector2(120, 28)
		btn.tooltip_text = "Inserta macro '%s' en el cursor" % macro_name
		add_child(btn)
		_buttons[macro_name] = btn