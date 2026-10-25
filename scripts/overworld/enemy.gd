extends Area2D
class_name Enemy

## Enemigo del overworld. Datos consumidos desde un EnemyData resource
## (configurado por el spawner). Mantiene exports como fallback para
## escenas que no usen EnemyData.

@export var display_name: String = "Bug Monster"
@export var max_hp: int = 100
@export var challenge_id: String = "main_exit_check"
## Segunda fase del enemigo, si la tiene. El cap 07 (fibonacci -> simple_dp)
## y el cap 08 (template_generic -> thread_join) son dos peleas del mismo
## enemigo: gana una, vuelve con la siguiente.
@export var challenge_id_next: String = ""
@export var respawn_time: float = 30.0
@export var enemy_id: String = ""  # id of the EnemyCatalog, optional
## El enemigo esta bloqueado: se ve, pero no se puede pelear con el hasta
## desbloquear el skill de su capitulo.
##
## ponytail: el gate antes NO lo spawneaba. El nivel se veia vacio y el
## jugador pensaba que le faltaba contenido (o que el juego estaba roto):
## "en el mapa solo veo 1". Ahora el enemigo bloqueado existe y esta
## dormido — gris, sin patrulla, sin pelea — con el skill que le falta
## escrito encima. La garantia del gate no cambia: la pelea no se puede
## ganar sin el skill.
@export var locked: bool = false
## ponytail: el enemigo tomaba la region del atlas A MANO en el .tscn
## (Rect2(0, 0, 320, 320)). El extractor regenera las hojas con otra
## geometria cada vez que cambia el arte, y un recorte escrito a mano
## queda viejo en silencio: el sprite mostraba media celda. Ahora la
## textura sale del SpriteFrames, que es quien sabe el tamano de celda.
@export var sprite_frames: SpriteFrames
@export var idle_anim: StringName = &"idle"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _is_defeated: bool = false
var _respawn_timer: SceneTreeTimer = null
var _lock_label: Label = null

func _ready() -> void:
	add_to_group("enemies")
	body_entered.connect(_on_body_entered)
	_apply_sprite_frames()
	if locked:
		_go_locked()


## El enemigo bloqueado: gris, sin colision y con el skill que falta.
func _go_locked() -> void:
	if sprite != null:
		sprite.modulate = Color(0.55, 0.55, 0.65, 0.75)
	set_deferred("monitoring", false)
	_show_lock_label()


## Despierta al enemigo: el skill se desbloqueo y ya se puede pelear.
func wake() -> void:
	if not locked:
		return
	locked = false
	if sprite != null:
		sprite.modulate = Color(1, 1, 1, 1)
	monitoring = true
	if _lock_label != null and is_instance_valid(_lock_label):
		_lock_label.queue_free()
		_lock_label = null


## El skill que le falta, escrito encima del enemigo.
func _show_lock_label() -> void:
	var skill_name: String = ""
	var challenge: ChallengeResource = ChallengeRegistry.get_by_id(challenge_id)
	if challenge != null:
		var info: Dictionary = SkillTree.skill_info(challenge.skill_id)
		skill_name = String(info.get("name", ""))
	if skill_name.is_empty():
		skill_name = "el skill de su capitulo"
	_lock_label = Label.new()
	_lock_label.text = "BLOQUEADO · %s" % skill_name
	_lock_label.add_theme_font_size_override("font_size", 11)
	_lock_label.add_theme_color_override("font_color", CyberStyleBox.AMBER)
	_lock_label.position = Vector2(-40, -74)
	_lock_label.size = Vector2(120, 16)
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lock_label)


## Toma el frame idle del SpriteFrames como textura del sprite.
func _apply_sprite_frames() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(idle_anim):
		return
	var frame: Texture2D = sprite_frames.get_frame_texture(idle_anim, 0)
	if frame != null:
		sprite.texture = frame

func _on_body_entered(body: Node2D) -> void:
	if _is_defeated or locked:
		return
	if not body.is_in_group("player"):
		return
	var data := EnemyData.create(display_name, max_hp, challenge_id, self, enemy_id)
	EventBus.battle_requested.emit(data.to_dict())

## Aplica los datos de un EnemyData (llamado por el spawner).
func apply_data(data: EnemyData) -> void:
	if data == null:
		return
	display_name = data.display_name
	max_hp = data.max_hp
	challenge_id = data.challenge_id
	respawn_time = data.respawn_time
	if data.node:
		enemy_id = String(data.node.name)

## Desactiva al enemigo e inicia el timer de respawn.
##
## ponytail: si el enemigo tiene segunda fase, NO desaparece: escala al
## siguiente challenge y sigue en el mundo. El capitulo es una secuencia de
## peleas contra el mismo enemigo, no dos enemigos distintos.
func defeat() -> void:
	if not challenge_id_next.is_empty():
		challenge_id = challenge_id_next
		challenge_id_next = ""
		return
	_is_defeated = true
	visible = false
	set_deferred("monitoring", false)
	_respawn_timer = get_tree().create_timer(respawn_time)
	_respawn_timer.timeout.connect(respawn)

## Reaparece el enemigo y reactiva la colisión.
func respawn() -> void:
	_is_defeated = false
	visible = true
	monitoring = true
	_respawn_timer = null
