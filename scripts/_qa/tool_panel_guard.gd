extends Node

## Guard del arsenal: las herramientas que el jugador gano aparecen en el
## panel de la derecha y se pueden soltar en el editor.
## Run: godot --headless scenes/qa/tool_panel_guard.tscn --quit-after 1200
##
## ponytail: estas herramientas son "modificadores corporales" del codigo:
## el jugador no escribe el for ni el if, lo arrastra. Antes eran una fila
## de botones abajo con seis macros; ahora son un panel lateral con trece
## herramientas arrastrables.

var _passed: Array = []
var _failed: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _run() -> void:
	# --- 1. cada macro de los skills existe en la libreria -------------------
	for skill_id in SkillTree.skills.keys():
		var node: SkillNode = SkillTree.skills[skill_id]
		for macro in node.macros_unlocked:
			_check(MacroBarUI.TOOLS.has(macro),
				"the skill '%s' brings a tool that exists ('%s')" % [skill_id, macro])

	# --- 2. el panel muestra lo desbloqueado y nada mas ---------------------
	var panel := MacroBarUI.new()
	add_child(panel)
	await get_tree().process_frame
	_check(panel.get_child_count() == 0,
		"the arsenal starts empty (nothing unlocked)")

	var unlocked := false
	for i in range(12):
		SkillTree.add_xp(200)
		# el nodo depende de la rama: primero la rama, despues el nodo
		SkillTree.try_unlock(&"branch_stl")
		if SkillTree.try_unlock(&"stl_loops"):
			unlocked = true
			break
	_check(unlocked, "the player can unlock the loops skill")
	await get_tree().process_frame
	_check(panel.get_child_count() >= 2,
		"the arsenal shows the tools of the unlocked skill (%d)" % panel.get_child_count())

	# cada tarjeta dice de donde salio
	var origins: Array = []
	for child in panel.get_children():
		if child is ToolCard:
			origins.append(child.origin)
	_check(origins.size() > 0 and String(origins[0]).contains("ganado con"),
		"each tool says where it came from (%s)" % str(origins))

	# --- 3. arrastrar una herramienta la inserta en el editor ---------------
	var edit := SnippetCodeEdit.new()
	add_child(edit)
	edit.insert_text_at_caret("int main() {")
	var tool_code: String = String(MacroBarUI.TOOLS["loop"]["code"])
	_check(edit._can_drop_data(Vector2.ZERO, {"tool_code": tool_code}),
		"the editor accepts a dragged tool")
	edit._drop_data(Vector2.ZERO, {"tool_code": tool_code})
	_check(edit.text.contains("for (int i = 0; i < n; i++)"),
		"dropping a tool inserts its code at the caret")
	_check(edit.text.begins_with("int main() {"),
		"the drop does not wipe what was already written")

	panel.editor = edit
	# el click tambien inserta (el arrastre es lo lindo, el clic lo seguro)
	var card: ToolCard = null
	for child in panel.get_children():
		if child is ToolCard and is_instance_valid(child):
			card = child
			break
	_check(card != null, "the arsenal has a draggable card")
	if card != null:
		edit.set_caret_line(0)
		card.insert_requested.emit(tool_code)
	_check(edit.text.count("for (int i = 0") == 2,
		"clicking a tool inserts it too")

	print("\n========== TOOL PANEL GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
