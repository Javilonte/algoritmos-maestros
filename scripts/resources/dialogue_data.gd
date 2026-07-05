class_name DialogueData
extends Resource

## Contenedor de líneas de diálogo para un NPC.
## Se asigna al NPC en el Inspector como un Resource exportado.

## Identificador único del NPC (para tracking de save/load futuro).
@export var npc_id: String = ""

## Nombre que se muestra en el UI del diálogo.
@export var display_name: String = "NPC"

## Secuencia de líneas que conforman la conversación.
@export var lines: Array[DialogueLine] = []:
	set(value):
		var typed: Array[DialogueLine] = []
		for item in value:
			if item is DialogueLine:
				typed.append(item)
			elif item is Resource:
				typed.append(item as DialogueLine)
		lines = typed

## Retorna true si hay al menos una línea definida.
func is_valid() -> bool:
	return not lines.is_empty()

## Retorna la primera línea del diálogo.
func get_first_line() -> DialogueLine:
	if lines.is_empty():
		return null
	return lines[0]

## Retorna la última línea del diálogo.
func get_last_line() -> DialogueLine:
	if lines.is_empty():
		return null
	return lines[lines.size() - 1]
