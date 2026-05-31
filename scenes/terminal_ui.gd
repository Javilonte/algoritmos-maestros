extends Control

@onready var code_editor = $CanvasLayer/Panel/CodeEdit
@onready var canvas = $CanvasLayer
@onready var consola_output = $CanvasLayer/Panel/ConsolaOutput
@onready var HTTP_request = $CanvasLayer/Panel/HTTPRequest 

const BACKEND_URL = "https://httpbin.org/post"

func _ready():
	#canvas.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	focus_mode = Control.FOCUS_ALL

	HTTP_request.request_completed.connect(_on_request_completed)

func _input(event):
	
	if event.is_action_pressed("ui_focus_next"):
		
		call_deferred("toggle_terminal")

func toggle_terminal():
	if canvas.visible:
		
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false
		canvas.hide()
		grab_focus()
	else:
		
		canvas.show()
		code_editor.grab_focus()
		get_tree().paused = true 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_compile_run_pressed():
	var player_code = code_editor.text
	#http request stillin mock
	consola_output.text = "[color=yellow]>>> Compilando y enviando código C++ al servidor MOCK...[/color]\n"
	
	var data_to_send = {
		"lenguaje": "cpp17",
		"codigo": player_code,
		"reto_id": "main_exit_check" 
	}
	
	var json_string = JSON.stringify(data_to_send)
	
	call_deferred("_send_code_to_backend", json_string)


func _send_code_to_backend(json_data: String):
	var headers = ["Content-Type: application/json"]
	

	var error = HTTP_request.request(BACKEND_URL, headers, HTTPClient.METHOD_POST, json_data)
	
	if error != OK:
		consola_output.text += "[color=red]ERROR DE RED: No se pudo conectar con el servidor MOCK.[/color]\n"


func _on_request_completed(_result, response_code, _headers, body):

	if response_code != 200:
		consola_output.text += "[color=red]ERROR DEL SERVIDOR: El servidor MOCK devolvió el código [/color]\n"
		consola_output.text += str(response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if json == null:
		consola_output.text += "[color=red]ERROR DE DATOS: La respuesta del servidor MOCK no es un JSON válido.[/color]\n"
		return
		
	var received_code = json.get("data", {}).get("codigo", "") 
	
	consola_output.text += "[color=cyan]>>> Respuesta del servidor MOCK recibida.[/color]\n"
	
	check_logic(received_code)

func check_logic(code: String):
	
	if "int main() { return 0; }" in code.to_lower(): 
		print("¡ALGORITMO C++ MINIMO DETECTADO! Daño infligido al monstruo.")
		toggle_terminal()
	else:
		print("ERROR DE SINTAXIS O LÓGICA (MOCK). Intenta de nuevo.")


func _on_button_2_pressed() -> void:
	var player_code = code_editor.text

	consola_output.text = "[color=yellow]>>> Compilando y enviando código C++ al servidor MOCK...[/color]\n"
	

	var data_to_send = {
		"lenguaje": "cpp17",
		"codigo": player_code,
		"reto_id": "main_exit_check" 
	}
	
	var json_string = JSON.stringify(data_to_send)
	
	call_deferred("_send_code_to_backend", json_string)


func _on_button_pressed() -> void:
	pass 
