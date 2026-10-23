extends Node2D
class_name IsoDungeon

## Dungeon isometrico estilo Diablo II.
## - BSP 50x50, 8 salas.
## - Cada sala spawnea 1 enemigo del EnemyCatalog.
## - Camara sigue al player.
## - Click izquierdo = move.

const DUNGEON_W := 50
const DUNGEON_H := 50
const NUM_ROOMS := 8
const DEFAULT_SEED := 1337

@export var seed: int = DEFAULT_SEED

@onready var world: Node2D = $World
@onready var entities: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D
@onready var player: IsoPlayer = $Entities/Player
@onready var enemy_spawner: Node = $EnemySpawner
@onready var lighting: CanvasLayer = $Lighting
@onready var dim_overlay: ColorRect = $Lighting/DimOverlay

var _dungeon_data: Dictionary = {}

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.OVERWORLD)
	_build_dungeon()

func _build_dungeon() -> void:
	# Generar grid BSP.
	_dungeon_data = BSPDungeonGenerator.generate(DUNGEON_W, DUNGEON_H, NUM_ROOMS, seed)
	var grid: Array = _dungeon_data["grid"]
	var rooms: Array = _dungeon_data["rooms"]

	# Crear tileset procedural.
	var build_result: Array = D2IsoTilesetBuilder.build()
	var tile_set: TileSet = build_result[0]
	var _texture: Texture2D = build_result[1]

	# Pintar dungeon.
	var origin := Vector2(640, 80)  # Centrar el dungeon en pantalla (50 tiles * 32 = 1600 ancho iso, pero la mitad visible).
	var painter_result: Dictionary = DungeonPainter.paint(grid, tile_set, tile_set.get_source(0) as TileSetAtlasSource, world, origin)

	# Configurar player en el centro de la primera sala.
	if rooms.size() > 0:
		var first_room: Rect2i = rooms[0]
		var start_grid: Vector2i = Vector2i(first_room.position.x + first_room.size.x / 2, first_room.position.y + first_room.size.y / 2)
		player.setup(origin, start_grid)
		camera.global_position = player.global_position

	# Spawnear enemigos (uno por sala, saltando la primera donde esta el player).
	_spawn_enemies(rooms, origin)

func _spawn_enemies(rooms: Array, origin: Vector2) -> void:
	# Distribuir enemigos del catalogo entre las salas (rotacion ciclica).
	var enemy_ids := EnemyCatalog.list_all()
	if enemy_ids.is_empty():
		return
	for i in range(1, rooms.size()):
		var room: Rect2i = rooms[i]
		var enemy_id: String = enemy_ids[(i - 1) % enemy_ids.size()]
		var enemy_data: Dictionary = EnemyCatalog.fetch(enemy_id)
		if enemy_data.is_empty():
			continue
		# Posicion aleatoria dentro de la sala.
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + i
		var ex: int = rng.randi_range(room.position.x, room.end.x - 1)
		var ey: int = rng.randi_range(room.position.y, room.end.y - 1)
		var pos: Vector2 = IsoMath.cartesian_to_screen(ex, ey, origin)
		# Spawnear sprite-enemigo.
		var enemy_sprite := _make_enemy_sprite(enemy_data)
		enemy_sprite.position = pos
		enemy_sprite.z_index = 10
		entities.add_child(enemy_sprite)
		# Metadata para interaccion.
		enemy_sprite.set_meta("enemy_id", enemy_id)
		enemy_sprite.set_meta("display_name", enemy_data.get("display_name", "Enemy"))
		enemy_sprite.set_meta("max_hp", enemy_data.get("max_hp", 100))
		enemy_sprite.set_meta("challenge_id", enemy_data.get("challenge_id", "slime_aritm"))
		enemy_sprite.set_meta("xp_reward", enemy_data.get("xp_reward", 50))

func _make_enemy_sprite(data: Dictionary) -> Sprite2D:
	# Sprite procedural: rombo rojo con la palabra del enemigo.
	var img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Rombo rojo sangre.
	var color: Color = data.get("color", D2Palette.HP_RED)
	for y in range(32):
		for x in range(48):
			var dx: float = absf(x - 24)
			var dy: float = absf(y - 16)
			if dx / 24.0 + dy / 16.0 <= 1.0:
				img.set_pixel(x, y, color)
	# Borde bronce.
	for y in range(32):
		for x in range(48):
			var dx: float = absf(x - 24)
			var dy: float = absf(y - 16)
			var inside: float = dx / 24.0 + dy / 16.0
			if inside > 0.85 and inside <= 1.0:
				img.set_pixel(x, y, D2Palette.BRONZE_DARK)
	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	return sprite

func _process(_delta: float) -> void:
	if player and camera:
		camera.global_position = camera.global_position.lerp(player.global_position, 0.1)
	_check_enemy_proximity()

const PROXIMITY_RADIUS := 36.0

func _check_enemy_proximity() -> void:
	if player == null:
		return
	for enemy in entities.get_children():
		if not enemy is Sprite2D:
			continue
		if enemy == player:
			continue
		if enemy.has_meta("defeated"):
			continue
		var dist: float = player.global_position.distance_to(enemy.global_position)
		if dist <= PROXIMITY_RADIUS and not enemy.has_meta("in_range"):
			enemy.set_meta("in_range", true)
			_show_interaction_hint(enemy)
		elif dist > PROXIMITY_RADIUS and enemy.has_meta("in_range"):
			enemy.remove_meta("in_range")
			_hide_interaction_hint(enemy)

func _show_interaction_hint(enemy: Node) -> void:
	if not enemy.has_node("Hint"):
		var hint := Label.new()
		hint.name = "Hint"
		hint.text = "Press E"
		hint.add_theme_color_override("font_color", D2Palette.GOLD_TEXT)
		hint.add_theme_font_size_override("font_size", 14)
		hint.position = Vector2(-18, -32)
		enemy.add_child(hint)

func _hide_interaction_hint(enemy: Node) -> void:
	if enemy.has_node("Hint"):
		enemy.get_node("Hint").queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# Buscar enemigo en rango.
		for enemy in entities.get_children():
			if not enemy is Sprite2D:
				continue
			if not enemy.has_meta("in_range"):
				continue
			if enemy.has_meta("defeated"):
				continue
			var enemy_id: String = String(enemy.get_meta("enemy_id"))
			var enemy_data: Dictionary = EnemyCatalog.fetch(enemy_id)
			if enemy_data.is_empty():
				continue
			# Construir EnemyData y emitir batalla.
			var battle_data := EnemyData.create(
				enemy_data.get("display_name", "Enemy"),
				int(enemy_data.get("max_hp", 100)),
				String(enemy_data.get("challenge_id", "slime_aritm")),
				null,
				enemy_id,
				int(enemy_data.get("xp_reward", 50))
			)
			enemy.set_meta("defeated", true)
			enemy.visible = false
			EventBus.battle_requested.emit(battle_data.to_dict())
			return
	# Escape: placeholder, no sale del dungeon por ahora.