extends Control

## Pantalla de selección de niveles.
##
## ponytail: las cartas son `MenuActionButton`, el botón tematizado que ya
## usa el menú principal. Un componente nuevo para las cartas habría sido
## la mitad del código repetido: el botón ya sabe hacer la variante cyan
## con borde, la etiqueta grande y la línea chica de abajo.
##
## El estado bloqueado lo declara el REGISTRO, no la pantalla: es contenido
## y la pantalla no debería inventar reglas de progresión que el juego
## todavía no tiene.

const WORLD_SCENE_PATH := "res://scenes/platformer/platformer_world.tscn"

@onready var grid: GridContainer = $Body/Grid
@onready var title_label: Label = $HeaderBar/TitlePadding/TitleLabel
@onready var hint_label: Label = $Footer/FooterPadding/HintLabel


func _ready() -> void:
	_apply_style()
	_build_cards()
	title_label.text = "NIVELES"
	hint_label.text = "ESC para volver"


func _apply_style() -> void:
	var background: Panel = get_node_or_null("Background")
	if background:
		background.add_theme_stylebox_override("panel", CyberStyleBox.backdrop())
	var header: Panel = get_node_or_null("HeaderBar")
	if header:
		header.add_theme_stylebox_override("panel", CyberStyleBox.bar())
	var footer: Panel = get_node_or_null("Footer")
	if footer:
		footer.add_theme_stylebox_override("panel", CyberStyleBox.footer_bar())
	var strip: Panel = get_node_or_null("HeaderBar/NeonStrip")
	if strip:
		strip.add_theme_stylebox_override("panel", CyberStyleBox.neon_strip())


func _build_cards() -> void:
	var levels: Array[Dictionary] = LevelRegistry.list_levels()
	for entry in levels:
		var id: String = String(entry["id"])
		var level: Dictionary = LevelRegistry.get_level(id)
		var unlocked: bool = bool(entry.get("unlocked", true))
		var card: MenuActionButton = MenuActionButton.new()
		card.variant = "primary" if unlocked else "subtle"
		card.disabled = not unlocked
		card.custom_minimum_size = Vector2(320, 74)
		card.icon_prefix = _level_number(id)
		card.text = String(entry.get("name", id)).to_upper()
		card.subtitle = _subtitle_for(entry, level, unlocked)
		card.pressed.connect(_on_level_pressed.bind(id))
		grid.add_child(card)
	if grid.get_child_count() > 0:
		var first: Node = grid.get_child(0)
		if first is Button:
			(first as Button).grab_focus()


func _level_number(id: String) -> String:
	var digits: String = id
	if digits.begins_with("level_"):
		digits = digits.substr(6)
	return "%02d" % int(digits)


func _subtitle_for(entry: Dictionary, level: Dictionary, unlocked: bool) -> String:
	if not unlocked:
		return "BLOQUEADO"
	var enemies: int = level.get("enemies", []).size()
	var chapter: String = String(entry.get("chapter", ""))
	if chapter.is_empty():
		return "%d enemigos" % enemies
	return "%s · %d enemigos" % [chapter.to_upper(), enemies]


func _on_level_pressed(id: String) -> void:
	GameManager.current_level_id = id
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
