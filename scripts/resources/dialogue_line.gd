class_name DialogueLine
extends Resource

## Línea individual de diálogo.
## Cada NPC habla a través de una secuencia de DialogueLines.

## Nombre del que habla.
@export var speaker: String = ""

## Texto que se muestra (soporta BBCode básico).
@export_multiline var text: String = ""

## Retrato del hablante (preparado para futuro sistema de retratos).
@export var portrait: Texture2D = null

## Tipo de evento que se dispara al terminar el diálogo.
## Valores soportados: "", "battle", "scene_change", "item", "custom"
@export var event_type: String = ""

## Datos del evento. Ejemplos:
## battle: {challenge_id: "main_exit_check", max_hp: 100}
## scene_change: {scene_path: "res://scenes/other.tscn"}
## item: {item_id: "key", quantity: 1}
@export var event_data: Dictionary = {}
