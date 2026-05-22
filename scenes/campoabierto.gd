extends Node2D

@export var speed: float = 300.0
# Usamos @onready para asegurar que el nodo Player1 ya cargó antes de buscarlo
@onready var player1: Sprite2D = $Player1

func _process(delta: float) -> void:
	# 1. Crear el vector de dirección
	var direction: Vector2 = Vector2.ZERO
	
	# 2. Detectar inputs
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
		
	# 3. Normalizar para diagonales
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		
	# 4. Modificar la POSICIÓN del Sprite2D directamente
	# Nota: Aquí SÍ multiplicamos por 'delta' para que el movimiento sea suave 
	# sin importar los bajones de FPS.
	player1.position += direction * speed * delta
