extends PanelContainer
class_name MenuStatsPanel

## ponytail: right column of the main menu. Surfaces the player's
## progression at a glance:
##   - Level badge with Lv N
##   - XP bar (uses HPBar with side="xp" — reused component)
##   - Skills (N/Total) with a dot per slot, locked or not
##   - Macros count
##   - Enemies (N/Total)
##   - "No save" prompt if SkillTree is at level 1 AND no save exists
##
## ponytail: era una PILA de etiquetas metidas arriba de un panel de 320
## px: 150 px de contenido y 200 de vacio, que se leia roto. Ahora es una
## lista de filas (etiqueta a la izquierda, valor a la derecha) separadas
## por lineas, y las filas se reparten el alto del panel.
##
## ponytail: el punto de habilidad bloqueado era oscuro sobre fondo
## oscuro: habia catorce ranuras y no se veia ni una. Y la barra de XP
## mostraba el "0%" del widget cuando al lado ya dice cuantos XP hay.

const TOTAL_SKILLS := 14
const TOTAL_ENEMIES := 10

@export var show_save_prompt: bool = true

var _level_badge_label: Label
var _xp_bar: HPBar
var _xp_label: Label
var _skills_label: Label
var _skills_value: Label
var _skills_row: HBoxContainer
var _macros_label: Label
var _macros_value: Label
var _macros_row: HBoxContainer
var _enemies_label: Label
var _enemies_value: Label
var _save_prompt: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", CyberStyleBox.card(CyberStyleBox.CYAN))
	_build()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Header: level badge + XP.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", CyberStyleBox.chip(CyberStyleBox.CYAN))
	header.add_child(badge)
	_level_badge_label = Label.new()
	_level_badge_label.text = "Lv 1"
	_level_badge_label.add_theme_color_override("font_color", CyberStyleBox.CYAN)
	_level_badge_label.add_theme_font_size_override("font_size", 15)
	badge.add_child(_level_badge_label)

	_xp_label = Label.new()
	_xp_label.text = "0 XP"
	_xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_label.add_theme_color_override("font_color", CyberStyleBox.TEXT)
	_xp_label.add_theme_font_size_override("font_size", 13)
	header.add_child(_xp_label)

	# XP bar. ponytail: sin el "0%" del widget — el numero ya esta al lado.
	_xp_bar = HPBar.new()
	_xp_bar.side = "xp"
	_xp_bar.percent_text = false
	_xp_bar.custom_minimum_size = Vector2(0, 10)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	vbox.add_child(_xp_bar)

	# Skills section.
	var skills_row := _section_row(vbox, "SKILLS")
	_skills_label = skills_row[0]
	_skills_value = skills_row[1]
	_skills_row = HBoxContainer.new()
	_skills_row.add_theme_constant_override("separation", 4)
	_skills_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_row[2].add_child(_skills_row)

	_separator(vbox)

	# Macros section.
	var macros_row := _section_row(vbox, "MACROS")
	_macros_label = macros_row[0]
	_macros_value = macros_row[1]
	_macros_row = HBoxContainer.new()
	_macros_row.add_theme_constant_override("separation", 4)
	_macros_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	macros_row[2].add_child(_macros_row)

	_separator(vbox)

	# Enemies section.
	var enemies_row := _section_row(vbox, "ENEMIES")
	_enemies_label = enemies_row[0]
	_enemies_value = enemies_row[1]

	_separator(vbox)

	# Save prompt. ponytail: se queda con el espacio que sobra abajo, que
	# es donde el ojo va a buscar "puedo seguir?". Siempre visible — con
	# partida guardada dice otra cosa — porque si se oculta el panel
	# queda con 200 px de vacio abajo.
	_save_prompt = Label.new()
	_save_prompt.text = "Sin partida guardada\nComienza tu viaje"
	_save_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_prompt.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	_save_prompt.add_theme_font_size_override("font_size", 12)
	_save_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD
	_save_prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_save_prompt)


## Una fila de seccion: etiqueta a la izquierda, valor a la derecha.
## ponytail: devuelve tambien el bloque (VBox) que envuelve la fila, para
## que la seccion entera — etiqueta y contenido — se reparta el alto del
## panel en vez de dejar 200 px de vacio entre secciones.
func _section_row(parent: Node, title: String) -> Array:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(block)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(row)

	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", CyberStyleBox.TEXT)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var value := Label.new()
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", CyberStyleBox.CYAN)
	value.add_theme_font_size_override("font_size", 13)
	row.add_child(value)

	return [label, value, block]


func _separator(parent: Node) -> void:
	var line := Panel.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_stylebox_override("panel", CyberStyleBox.separator())
	parent.add_child(line)


## ponytail: refresh from SkillTree. Safe to call when the autoload
## is missing (the menu is shown at app boot, before SkillTree may
## be ready in some edge cases).
func refresh_from_skill_tree() -> void:
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		# ponytail: SkillTree is the autoload; if missing we can't
		# render real stats. Show the "no save" prompt as a fallback.
		_apply_no_save_state()
		return

	var level: int = int(st.get("current_level")) if "current_level" in st else 1
	var xp: int = int(st.get("current_xp")) if "current_xp" in st else 0
	if _level_badge_label:
		_level_badge_label.text = "Lv %d" % level
	if _xp_label:
		_xp_label.text = "%d XP" % xp
	# Update XP bar to (current / to_next) ratio.
	if _xp_bar:
		var to_next: int = int(st._xp_for_next_level()) if st.has_method("_xp_for_next_level") else 100
		_xp_bar.max_value = max(1, to_next)
		_xp_bar.value = clamp(xp, 0, to_next)

	_refresh_skills(st)
	_refresh_macros(st)
	_refresh_enemies(st)
	_refresh_save_prompt()


## ponytail: connect to SkillTree signals (idempotent).
func connect_to_skill_tree() -> void:
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		return
	for sig_name in ["skill_unlocked", "level_changed", "xp_changed"]:
		if st.has_signal(sig_name) and not st.get(sig_name).is_connected(_on_skill_tree_signal):
			st.get(sig_name).connect(_on_skill_tree_signal)
	refresh_from_skill_tree()


func _on_skill_tree_signal(_a = null, _b = null, _c = null) -> void:
	refresh_from_skill_tree()


func _refresh_skills(st: Node) -> void:
	if _skills_row == null:
		return
	_clear_row(_skills_row)
	var unlocked: int = 0
	if st.has_method("skills"):
		var skills_dict: Dictionary = st.skills
		for id in skills_dict:
			var n: SkillNode = skills_dict[id]
			if n.unlocked:
				unlocked += 1
	# ponytail: un punto por ranura, bloqueada o no. Los dots NO
	# representan una habilidad en particular: son un contador. Los
	# primeros `unlocked` quedan encendidos y el resto apagados. Antes
	# el estado de cada dot salia de recorrer el Dictionary por
	# posicion, asi que que punto estaba encendido dependia del orden
	# de iteracion y no de nada que el jugador pueda leer.
	for i in TOTAL_SKILLS:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.add_theme_stylebox_override("panel", CyberStyleBox.dot(i < unlocked))
		_skills_row.add_child(dot)
	if _skills_value:
		_skills_value.text = "%d/%d" % [unlocked, TOTAL_SKILLS]


func _refresh_macros(st: Node) -> void:
	if _macros_row == null:
		return
	_clear_row(_macros_row)
	var macros: PackedStringArray = PackedStringArray()
	if st.has_method("get_unlocked_macros"):
		macros = st.get_unlocked_macros()
	for m in macros:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", CyberStyleBox.chip(CyberStyleBox.CYAN))
		var label := Label.new()
		label.text = String(m)
		label.add_theme_color_override("font_color", CyberStyleBox.CYAN)
		label.add_theme_font_size_override("font_size", 10)
		badge.add_child(label)
		_macros_row.add_child(badge)
	if _macros_value:
		_macros_value.text = "%d" % macros.size()


func _refresh_enemies(st: Node) -> void:
	if _enemies_value == null:
		return
	var unlocked: int = 0
	if st.has_method("get_unlocked_enemies"):
		var enemies: PackedStringArray = st.get_unlocked_enemies()
		unlocked = enemies.size()
	_enemies_value.text = "%d/%d" % [unlocked, TOTAL_ENEMIES]


## ponytail: vaciar una fila con queue_free() NO alcanza: la liberacion
## se difiere al final del frame, asi que los puntos viejos seguian
## siendo hijos cuando los nuevos se agregaban y la fila acumulaba
## (catorce puntos mas catorce = veintiocho). Sacarlos del arbol antes
## de encolar la liberacion los descarta de verdad.
func _clear_row(row: Node) -> void:
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _refresh_save_prompt() -> void:
	if _save_prompt == null:
		return
	var has_save: bool = false
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("has_save"):
		has_save = sm.has_save()
	# ponytail: el panel se ve igual con o sin partida: lo que cambia es
	# el texto. Ocultarlo dejaba el panel con un hueco de 200 px abajo.
	_save_prompt.text = "Partida guardada\nContinúa donde lo dejaste" if has_save \
		else "Sin partida guardada\nComienza tu viaje"
	_save_prompt.visible = show_save_prompt


func _apply_no_save_state() -> void:
	if _level_badge_label:
		_level_badge_label.text = "Lv 1"
	if _xp_label:
		_xp_label.text = "0 XP"
	if _xp_bar:
		_xp_bar.value = 0
	_clear_row(_skills_row)
	_clear_row(_macros_row)
	if _skills_value:
		_skills_value.text = "0/%d" % TOTAL_SKILLS
	if _macros_value:
		_macros_value.text = "0"
	if _enemies_value:
		_enemies_value.text = "0/%d" % TOTAL_ENEMIES
	_refresh_save_prompt()
