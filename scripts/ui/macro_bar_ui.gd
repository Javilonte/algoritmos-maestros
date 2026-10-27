extends VBoxContainer
class_name MacroBarUI

## El arsenal: las herramientas que el jugador gano, a la derecha del
## editor. Cada una es un fragmento de C++ que se ARRASTRA al editor (o se
## clica) y se inserta en el cursor.
##
## ponytail: esto solia ser una barra horizontal de botones abajo, con
## seis macros. El pedido era mejor: un panel lateral con herramientas
## que se ganan, y arrastrables. Las herramientas siguen viniendo de los
## SKILLS (cada skill trae la de su concepto: el de los bucles trae el
## `for`), y cada enemigo del capitulo es el que da la XP que abre el
## skill. El panel dice de donde salio cada una.

## Las herramientas: id -> {name, desc, code}.
const TOOLS: Dictionary = {
	"if": {
		"name": "Si",
		"desc": "Un if con su bloque.",
		"code": "if (condicion) {\n    // ...\n}",
	},
	"if_else": {
		"name": "Si / Sino",
		"desc": "Las dos ramas del condicional.",
		"code": "if (condicion) {\n    // ...\n} else {\n    // ...\n}",
	},
	"loop": {
		"name": "For",
		"desc": "El bucle con contador.",
		"code": "for (int i = 0; i < n; i++) {\n    // ...\n}",
	},
	"while": {
		"name": "While",
		"desc": "Repite mientras la condicion siga siendo cierta.",
		"code": "while (condicion) {\n    // ...\n}",
	},
	"range_for": {
		"name": "For de coleccion",
		"desc": "Recorre un vector, elemento por elemento.",
		"code": "for (auto valor : coleccion) {\n    // ...\n}",
	},
	"vector": {
		"name": "Vector",
		"desc": "Un vector<int> vacio.",
		"code": "std::vector<int> v;",
	},
	"bubble_sort": {
		"name": "Bubble sort",
		"desc": "El esqueleto del sort propio: dos bucles anidados.",
		"code": "for (int i = 0; i < n - 1; i++) {\n    for (int j = 0; j < n - 1 - i; j++) {\n        if (arr[j] > arr[j + 1]) { std::swap(arr[j], arr[j + 1]); }\n    }\n}",
	},
	"sort": {
		"name": "Ordenar",
		"desc": "std::sort sobre un vector.",
		"code": "std::sort(arr.begin(), arr.end());",
	},
	"binary": {
		"name": "Buscar",
		"desc": "lower_bound: buscar en un vector ordenado.",
		"code": "auto it = std::lower_bound(arr.begin(), arr.end(), target);\nif (it != arr.end() && *it == target) { /* encontrado */ }",
	},
	"hash": {
		"name": "Mapa",
		"desc": "un unordered_map y el bucle que lo llena.",
		"code": "std::unordered_map<int, int> seen;\nfor (int v : arr) { seen[v]++; }",
	},
	"free": {
		"name": "Liberar",
		"desc": "new y delete: la memoria que pediste, la devolvés.",
		"code": "int* p = new int(0);\n// ...\ndelete p;",
	},
	"recursion": {
		"name": "Recursion",
		"desc": "El caso recursivo de f(n).",
		"code": "return f(n - 1) + f(n - 2);",
	},
	"template": {
		"name": "Template",
		"desc": "Una funcion generica que sirve para cualquier tipo.",
		"code": "template <typename T>\nT maximo(vector<T> v) {\n    T best = v[0];\n    for (auto x : v) { if (x > best) best = x; }\n    return best;\n}",
	},
	"thread": {
		"name": "Hilo",
		"desc": "Un std::thread y su join.",
		"code": "std::thread t([&total]() { /* trabajo */ });\nt.join();",
	},
}

## El editor al que se insertan las herramientas. El panel vive DENTRO del
## terminal, asi que no tiene por que adivinar cual esta enfocado.
var editor: CodeEdit = null

var _cards: Array = []


func _ready() -> void:
	_style()
	var tree := get_node_or_null("/root/SkillTree") as SkillTreeData
	if tree:
		if not tree.skill_unlocked.is_connected(_on_skill_unlocked):
			tree.skill_unlocked.connect(_on_skill_unlocked)
	_refresh()


func _style() -> void:
	add_theme_constant_override("separation", 8)


func _on_skill_unlocked(_skill_id: StringName) -> void:
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()
	_cards.clear()
	var tree := get_node_or_null("/root/SkillTree") as SkillTreeData
	if tree == null:
		return
	var seen: Array = []
	for macro_name in tree.get_unlocked_macros():
		if macro_name in seen:
			continue
		seen.append(macro_name)
		var data: Dictionary = TOOLS.get(macro_name, {})
		if data.is_empty():
			data = {"name": macro_name, "desc": "", "code": "// " + macro_name}
		var card := ToolCard.new()
		card.setup(macro_name, data, _origin_of(tree, macro_name))
		card.insert_requested.connect(_on_insert_requested)
		add_child(card)
		_cards.append(card)


## De que skill vino la herramienta: el panel lo dice, para que el jugador
## entienda por que la tiene.
func _origin_of(tree: SkillTreeData, macro_name: String) -> String:
	for skill_id in tree.skills.keys():
		var node: SkillNode = tree.skills[skill_id]
		if macro_name in node.macros_unlocked:
			return "ganado con: %s" % node.display_name
	return ""


func _on_insert_requested(code: String) -> void:
	print("      DEBUG panel: insert pedido, len=", code.length(), " code=[", code.substr(0, 30), "] editor=", editor)
	var code_edit: CodeEdit = editor if editor != null else _find_active_code_edit()
	if code_edit != null:
		code_edit.insert_text_at_caret(code)
		code_edit.grab_focus()
	else:
		DisplayServer.clipboard_set(code)


## ponytail: find the first CodeEdit with focus. We look at the
## viewport's gui_get_focus_owner first, then fall back to scanning
## the tree for a CodeEdit whose has_focus() returns true.
func _find_active_code_edit() -> CodeEdit:
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	if focused is CodeEdit:
		return focused
	return _scan_for_focused_code_edit(get_tree().root)


func _scan_for_focused_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit and (node as CodeEdit).has_focus():
		return node
	for child in node.get_children():
		var hit: CodeEdit = _scan_for_focused_code_edit(child)
		if hit != null:
			return hit
	return null
