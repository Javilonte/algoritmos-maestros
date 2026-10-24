extends PanelContainer
class_name MenuHeroCard

## ponytail: left column of the main menu. Shows the player character
## idle on a floor line with a name/level strip below.
## Auto-binds to a SpriteFrames resource and listens to SkillTree
## changes so the name reflects the current level/XP.
##
## ponytail: el sprite usaba un CenterContainer, que no mueve un Node2D:
## el personaje se dibujaba medio fuera del marco (46 px a la izquierda,
## 72 px por encima) y con una escala absoluta de 0.4 que se rompia en
## cuanto el extractor cambiaba la geometria de la hoja. Ahora cuelga del
## panel de arte y lo posiciona SpriteInFrame.

@export var sprite_frames: SpriteFrames
@export var default_name: String = "Player"
## Fraccion del area de arte que puede ocupar el personaje.
@export var portrait_fill: float = 0.95

var _sprite: AnimatedSprite2D
var _name_label: Label
var _level_label: Label
var _subtitle_label: Label
var _art_panel: Panel


func _ready() -> void:
	add_theme_stylebox_override("panel", CyberStyleBox.card(CyberStyleBox.CYAN))
	_build()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Area de arte: fondo oscuro con linea de piso, sin borde propio.
	_art_panel = Panel.new()
	_art_panel.custom_minimum_size = Vector2(200, 300)
	_art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_panel.add_theme_stylebox_override("panel", CyberStyleBox.art_backdrop(CyberStyleBox.CYAN))
	_art_panel.resized.connect(_layout_sprite)
	vbox.add_child(_art_panel)

	if sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = sprite_frames
		_sprite.autoplay = "idle"
		_sprite.animation = "idle"
		_art_panel.add_child(_sprite)
		_layout_sprite.call_deferred()

	# Header row: name a la izquierda, nivel a la derecha.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.text = default_name
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.add_theme_color_override("font_color", CyberStyleBox.CYAN)
	_name_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_name_label)

	_level_label = Label.new()
	_level_label.text = "Lv 1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	_level_label.add_theme_font_size_override("font_size", 13)
	header.add_child(_level_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Sin partida guardada"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_subtitle_label)


## El sprite es un Node2D: lo posiciona SpriteInFrame contra el area real.
func _layout_sprite() -> void:
	SpriteInFrame.fit(_sprite, _art_panel, portrait_fill)


## ponytail: refresh from SkillTree. Safe to call before the autoload
## is ready (returns silently).
func refresh_from_skill_tree() -> void:
	if not Engine.has_singleton("SkillTree") and get_node_or_null("/root/SkillTree") == null:
		return
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		return
	var level: int = int(st.get("current_level")) if "current_level" in st else 1
	var xp: int = int(st.get("current_xp")) if "current_xp" in st else 0
	if _level_label:
		_level_label.text = "Lv %d · %d XP" % [level, xp]
	if _subtitle_label:
		_subtitle_label.text = "Tu viaje por los algoritmos"


## ponytail: connect to SkillTree once (call after instantiation).
func connect_to_skill_tree() -> void:
	var st: Node = get_node_or_null("/root/SkillTree")
	if st == null:
		return
	if st.has_signal("level_changed") and not st.level_changed.is_connected(_on_level_changed):
		st.level_changed.connect(_on_level_changed)
	if st.has_signal("xp_changed") and not st.xp_changed.is_connected(_on_xp_changed):
		st.xp_changed.connect(_on_xp_changed)
	refresh_from_skill_tree()


func _on_level_changed(_new_level: int) -> void:
	refresh_from_skill_tree()


func _on_xp_changed(_current: int, _to_next: int) -> void:
	refresh_from_skill_tree()
