extends CodeEdit
class_name SnippetCodeEdit

## El editor que acepta herramientas arrastradas.
##
## ponytail: el CodeEdit de Godot solo acepta texto arrastrado. Para que
## una herramienta del arsenal (un `for`, un `if`) se pueda soltar ENCIMA
## del editor, hace falta interceptar el drop: si lo que se arrastra trae
## "tool_code", se inserta en el cursor.

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("tool_code")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("tool_code"):
		insert_text_at_caret(String(data["tool_code"]))
		grab_focus()
