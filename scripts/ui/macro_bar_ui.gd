extends HBoxContainer
class_name MacroBarUI

## UI que muestra las macros desbloqueadas.
## Se actualiza cuando el SkillTree (autoload /root/SkillTree) emite skill_unlocked.
##
## ponytail: clicking a button now inserts the macro into the active
## CodeEdit (the BattleTerminal's editor) — this was the missing piece
## that made the bar visible-but-non-functional before.

var _buttons: Dictionary = {}
var _tree: SkillTreeData

## Map of macro name → text to insert at the cursor.
## ponytail: keep the templates here so they're easy to extend without
## touching SkillTree. The key is the macro identifier stored in
## SkillNode.macros_unlocked.
const MACRO_TEMPLATES: Dictionary = {
	"sort":   "std::sort(arr.begin(), arr.end());",
	"free":   "// free:",
	"binary": "auto it = std::lower_bound(arr.begin(), arr.end(), target);\nif (it != arr.end() && *it == target) { /* found */ }",
	"loop":   "for (int i = 0; i < n; i++) {\n    // ...\n}",
	"hash":   "std::unordered_map<int, int> seen;\nfor (int v : arr) { seen[v]++; }",
	"recursion": "return f(n - 1) + f(n - 2);",
}

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
		btn.pressed.connect(_on_macro_button_pressed.bind(macro_name))
		add_child(btn)
		_buttons[macro_name] = btn


## ponytail: button click handler — inserts the macro text into the
## currently-focused CodeEdit. If no editor is focused, the macro is
## pushed to the system clipboard as a fallback.
func _on_macro_button_pressed(macro_name: String) -> void:
	var template: String = String(MACRO_TEMPLATES.get(macro_name, "// " + macro_name))
	var code_edit: CodeEdit = _find_active_code_edit()
	if code_edit != null:
		code_edit.insert_text_at_cursor(template)
		# Give the editor focus so the user can keep typing.
		code_edit.grab_focus()
	else:
		DisplayServer.clipboard_set(template)
		# ponytail: gentle nudge via console so the player knows what happened.
		print("[MacroBar] No editor focused — copied '%s' to clipboard." % macro_name)


## ponytail: find the first CodeEdit with focus. We look at the
## viewport's gui_get_focus_owner first, then fall back to scanning
## the tree for a CodeEdit whose has_focus() returns true.
func _find_active_code_edit() -> CodeEdit:
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	if focused is CodeEdit:
		return focused
	# Fallback: scan the tree for any focused CodeEdit.
	var found: CodeEdit = _scan_for_focused_code_edit(get_tree().root)
	return found


func _scan_for_focused_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit and (node as CodeEdit).has_focus():
		return node
	for child in node.get_children():
		var hit: CodeEdit = _scan_for_focused_code_edit(child)
		if hit != null:
			return hit
	return null