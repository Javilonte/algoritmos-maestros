extends Control

@onready var code_editor = $CanvasLayer/Panel/CodeEdit
@onready var canvas = $CanvasLayer

func _ready():
	canvas.hide() # Empezamos con la terminal oculta
	process_mode = Node.PROCESS_MODE_ALWAYS # Esto permite que la terminal funcione aunque el juego esté pausado

func _input(event):
	# Usaremos la tecla "TAB" para abrir/cerrar (en Godot es ui_focus_next por defecto)
	if event.is_action_pressed("ui_focus_next"):
		toggle_terminal()

func toggle_terminal():
	if canvas.visible:
		# CERRAR TERMINAL
		canvas.hide()
		get_tree().paused = false # Reanudamos el juego
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # El mouse vuelve al juego
	else:
		# ABRIR TERMINAL
		canvas.show()
		code_editor.grab_focus() # Para poder escribir de inmediato
		get_tree().paused = true # PAUSAMOS EL MUNDO (estilo LeetCode)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Liberamos el mouse

# Función para "Ejecutar" el código (la llamaremos con un botón o tecla)
func _on_run_button_pressed():
	var player_code = code_editor.text
	check_logic(player_code)

func check_logic(code: String):
	# Por ahora, una validación "Mock" (falsa) para pruebas
	if "return true" in code:
		print("¡ALGORITMO CORRECTO! Daño infligido.")
		toggle_terminal() # Cerramos y volvemos a la acción
	else:
		print("ERROR DE SINTAXIS O LÓGICA. Intenta de nuevo.")