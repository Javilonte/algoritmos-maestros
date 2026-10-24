extends PanelContainer
class_name BattlePortrait

## Una ficha de combate: nombre + nivel + arte animado + barra de HP.
##
## Usada para el jugador y el enemigo en BattleArena. Muestra la animacion
## `idle` y cambia a `hurt` un instante cuando recibe dano.
##
## ponytail: antes el retrato usaba un CenterContainer para centrar el
## sprite. Los contenedores SOLO ordenan hijos Control, y un
## AnimatedSprite2D es un Node2D: nunca se movia. Con `centered = true`
## se dibujaba desde -size/2 alrededor del origen, o sea medio personaje
## FUERA del marco. Medido: el arte del enemigo caia en y = -8.4, por
## encima del tope de la pantalla, tapando el nombre y el borde.
## Ahora el sprite cuelga del panel de arte y se posiciona a mano contra
## su `resized`.
##
## ponytail: la escala se derivaba de SIGIL_SIZE (160x180), una constante
## que ya no media nada: el area real de arte es 224x223 y ambas imagenes
## salian de 150.88 px de alto por pura coincidencia. Ahora la escala sale
## del rect REAL del area de arte.

@export var sprite_frames: SpriteFrames
@export var idle_anim: StringName = &"idle"
@export var hurt_anim: StringName = &"hurt"
## Fraccion del area de arte que puede ocupar el retrato. El arte se escala
## SOLO para entrar: una escala absoluta se rompia en cada cambio de
## geometria del atlas y dejaba al personaje colgando del recuadro.
@export var portrait_fill: float = 0.92
@export var display_name: String = "???"
@export var level: int = 1
@export var side: String = "enemy"  # "enemy" or "player"

## Margen lateral del area de arte. Abajo no hay margen: el borde inferior
## del panel es la linea de piso sobre la que se apoya el personaje.
const ART_PADDING := SpriteInFrame.PADDING

var _sprite: AnimatedSprite2D
var _name_label: Label
var _level_label: Label
var _hp_bar: HPBar
var _hp_value_label: Label
var _art: Panel
var _default_anim: StringName


func _ready() -> void:
	_apply_style()
	_build()


## Acento neon del lado: cyan para el jugador, magenta para el enemigo.
func _accent() -> Color:
	return CyberStyleBox.CYAN if side == "player" else CyberStyleBox.MAGENTA


func _apply_style() -> void:
	add_theme_stylebox_override("panel", CyberStyleBox.card(_accent()))


func _build() -> void:
	# Columna interior: nombre+nivel, arte, HP.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# Header: nombre a la izquierda, nivel a la derecha. Antes el nombre
	# se centraba en una etiqueta de 195 px y el nivel se clavaba en el
	# borde, dejando 100 px de hueco entre los dos.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.text = display_name
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.add_theme_color_override("font_color", _accent())
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_name_label)

	_level_label = Label.new()
	_level_label.text = "Lv %d" % level
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	_level_label.add_theme_font_size_override("font_size", 13)
	header.add_child(_level_label)

	# Area de arte: fondo oscuro con linea de piso, sin borde propio.
	_art = Panel.new()
	_art.custom_minimum_size = Vector2(180, 200)
	_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.add_theme_stylebox_override("panel", CyberStyleBox.art_backdrop(_accent()))
	_art.resized.connect(_layout_sprite)
	vbox.add_child(_art)

	if sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = sprite_frames
		_sprite.autoplay = String(idle_anim)
		_sprite.animation = String(idle_anim)
		_art.add_child(_sprite)
		_default_anim = idle_anim
		_layout_sprite.call_deferred()

	# Fila de metadatos de HP: la etiqueta y el valor van EN SU PROPIA
	# fila para que la barra de abajo ocupe el ancho completo de la carta.
	var hp_meta := HBoxContainer.new()
	hp_meta.add_theme_constant_override("separation", 8)
	vbox.add_child(hp_meta)

	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_color_override("font_color", CyberStyleBox.TEXT_DIM)
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_meta.add_child(hp_label)

	_hp_value_label = Label.new()
	_hp_value_label.text = "0/0"
	_hp_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_value_label.add_theme_color_override("font_color", CyberStyleBox.TEXT)
	_hp_value_label.add_theme_font_size_override("font_size", 12)
	hp_meta.add_child(_hp_value_label)

	_hp_bar = HPBar.new()
	_hp_bar.side = side
	_hp_bar.percent_text = false
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(_hp_bar)


## ponytail: el sprite es un Node2D, no lo toca ningun contenedor. Se
## posiciona a mano contra el area de arte: centrado en X, apoyado sobre
## la linea de piso en Y, y escalado contra el tamano REAL de esa area.
## La aritmetica vive en SpriteInFrame, que la comparte con la ficha del
## menu principal.
func _layout_sprite() -> void:
	SpriteInFrame.fit(_sprite, _art, portrait_fill)


## Update the displayed name and level.
func set_identity(name: String, p_level: int) -> void:
	display_name = name
	level = p_level
	if _name_label:
		_name_label.text = name
	if _level_label:
		_level_label.text = "Lv %d" % p_level


## Update the HP bar.
func set_hp(current: int, max_hp: int) -> void:
	if _hp_bar:
		_hp_bar.set_hp(current, max_hp)
	if _hp_value_label:
		_hp_value_label.text = "%d/%d" % [current, max_hp]


## Briefly play the `hurt` animation then return to idle.
func flash_hurt() -> void:
	if _sprite == null or sprite_frames == null:
		return
	if not sprite_frames.has_animation(hurt_anim):
		return
	_sprite.play(hurt_anim)
	await get_tree().create_timer(0.4).timeout
	if _sprite != null:
		_sprite.play(_default_anim)
