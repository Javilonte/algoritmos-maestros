extends Area2D
class_name PlatformerCheckpoint

## Punto de reaparición del nivel. El jugador lo activa al pisarlo y el
## mundo guarda la posición como destino del respawn.
##
## ponytail: el color dice el estado sin texto: apagado (cyan apagado) es
## "todavía no llegaste", encendido (magenta) es "esto ya está guardado".
## Un cartel con la palabra CHECKPOINT sería ruido.

signal activated(checkpoint: PlatformerCheckpoint)

const PILLAR_HEIGHT: float = 72.0

@onready var pillar: ColorRect = $Pillar
@onready var glow: ColorRect = $Glow

var _active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_state()


## La posición donde el jugador reaparece.
func get_checkpoint_position() -> Vector2:
	return global_position


func is_active() -> bool:
	return _active


func _on_body_entered(body: Node2D) -> void:
	if _active or body == null or not body.is_in_group("player"):
		return
	_active = true
	_apply_state()
	activated.emit(self)


func _apply_state() -> void:
	var color: Color = CyberStyleBox.MAGENTA if _active else Color(0.0, 0.35, 0.32)
	if pillar != null:
		pillar.color = color
	if glow != null:
		glow.color = Color(color.r, color.g, color.b, 0.18 if _active else 0.08)
