class_name BSPDungeonGenerator

## Generador de dungeon BSP (Binary Space Partitioning).
##
## Produce un grid 50x50 con 8 salas conectadas por corredores.
##
## Pipeline:
##   1. Inicializar grid = muro.
##   2. BSP recursivo: split inteligente hasta tener target_leaves.
##   3. Cada hoja tallar una sala rectangular.
##   4. Conectar salas en orden BSP con corredores en L.
##
## Salida:
##   grid: Array[Array[int]] con TILE_*. Dimensiones grid_h x grid_w.
##   rooms: Array[Rect2i] (x, y, w, h) en coords cartesianas.
##
## Sin assets externos. Determinista por seed.

const TILE_VOID := -1
const TILE_WALL := D2IsoTilesetBuilder.T_WALL_N
const TILE_FLOOR := D2IsoTilesetBuilder.T_FLOOR

const MIN_LEAF_SIZE := 10
const MIN_ROOM_SIZE := 3
const MAX_ROOM_SIZE := 7
const WALL_PADDING := 1

class BSPNode:
	var x: int = 0
	var y: int = 0
	var w: int = 0
	var h: int = 0
	var left: BSPNode = null
	var right: BSPNode = null
	var room: Rect2i = Rect2i()
	var is_leaf: bool = false

	func _init(p_x: int, p_y: int, p_w: int, p_h: int) -> void:
		x = p_x
		y = p_y
		w = p_w
		h = p_h

	func carve_room(rng: RandomNumberGenerator) -> void:
		var rw: int = clampi(rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE), MIN_ROOM_SIZE, max(w - WALL_PADDING * 2, MIN_ROOM_SIZE))
		var rh: int = clampi(rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE), MIN_ROOM_SIZE, max(h - WALL_PADDING * 2, MIN_ROOM_SIZE))
		var rx: int = clampi(rng.randi_range(x + WALL_PADDING, x + w - rw - WALL_PADDING), x + WALL_PADDING, x + w - rw - WALL_PADDING)
		var ry: int = clampi(rng.randi_range(y + WALL_PADDING, y + h - rh - WALL_PADDING), y + WALL_PADDING, y + h - rh - WALL_PADDING)
		room = Rect2i(rx, ry, rw, rh)

	func collect_leaves(out: Array) -> void:
		if is_leaf:
			out.append(self)
			return
		if left:
			left.collect_leaves(out)
		if right:
			right.collect_leaves(out)

	func collect_all_rooms(out: Array) -> void:
		if is_leaf and room != Rect2i():
			out.append(room)
			return
		if left:
			left.collect_all_rooms(out)
		if right:
			right.collect_all_rooms(out)

	func center() -> Vector2i:
		if is_leaf and room != Rect2i():
			return Vector2i(room.position.x + room.size.x / 2, room.position.y + room.size.y / 2)
		if left and right:
			var lc: Vector2i = left.center()
			var rc: Vector2i = right.center()
			return Vector2i((lc.x + rc.x) / 2, (lc.y + rc.y) / 2)
		return Vector2i(x + w / 2, y + h / 2)

## Divide el nodo en 2 hijos. Devuelve true si la division ocurrio.
	func try_split(rng: RandomNumberGenerator, can_split_h: bool, can_split_v: bool) -> void:
		var split_horizontal: bool = rng.randf() < 0.5
		if split_horizontal and can_split_h:
			var h1: int = clampi(int(h * 0.5) + rng.randi_range(-3, 3), MIN_LEAF_SIZE, h - MIN_LEAF_SIZE)
			left = BSPNode.new(x, y, w, h1)
			right = BSPNode.new(x, y + h1, w, h - h1)
		elif can_split_v:
			var w1: int = clampi(int(w * 0.5) + rng.randi_range(-3, 3), MIN_LEAF_SIZE, w - MIN_LEAF_SIZE)
			left = BSPNode.new(x, y, w1, h)
			right = BSPNode.new(x + w1, y, w - w1, h)
		else:
			is_leaf = true

## Genera un dungeon. Devuelve un dict con grid, rooms, width, height, seed.
static func generate(width: int, height: int, target_leaves: int, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := BSPNode.new(0, 0, width, height)
	# Algoritmo BSP adaptativo: usa una cola de nodos pendientes por dividir.
	# Se detiene cuando tenemos >= target_leaves hojas.
	var all_nodes: Array = [root]
	var leaves: Array = []
	while leaves.size() < target_leaves and all_nodes.size() > 0:
		var node: BSPNode = all_nodes.pop_back()
		if node == null:
			continue
		var can_split_h: bool = node.h >= MIN_LEAF_SIZE * 2
		var can_split_v: bool = node.w >= MIN_LEAF_SIZE * 2
		if not can_split_h and not can_split_v:
			node.is_leaf = true
			leaves.append(node)
			continue
		node.try_split(rng, can_split_h, can_split_v)
		if node.is_leaf:
			leaves.append(node)
		else:
			all_nodes.append(node.left)
			all_nodes.append(node.right)

	for leaf in leaves:
		leaf.carve_room(rng)

	var grid: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(TILE_WALL)
		grid.append(row)

	var rooms: Array = []
	for leaf in leaves:
		if leaf.room == Rect2i():
			continue
		# Clip room a los limites del grid.
		var room: Rect2i = leaf.room
		var rx_start: int = clampi(room.position.x, 0, max(width - 1, 0))
		var rx_end: int = clampi(room.end.x, 0, max(width, 0))
		var ry_start: int = clampi(room.position.y, 0, max(height - 1, 0))
		var ry_end: int = clampi(room.end.y, 0, max(height, 0))
		# Solo agregar sala si tiene al menos 1x1 tile valido.
		if rx_start >= width or ry_start >= height or rx_end <= rx_start or ry_end <= ry_start:
			continue
		# Re-empaquetar como Rect2i con dimensiones validas.
		var rx_w: int = maxi(rx_end - rx_start, 1)
		var ry_h: int = maxi(ry_end - ry_start, 1)
		rooms.append(Rect2i(rx_start, ry_start, rx_w, ry_h))
		for ry in range(ry_start, ry_end):
			for rx in range(rx_start, rx_end):
				grid[ry][rx] = TILE_FLOOR

	_connect_rooms_bsp(root, grid, rooms)

	for ry in range(height):
		grid[ry][0] = TILE_WALL
		grid[ry][width - 1] = TILE_WALL
	for rx in range(width):
		grid[0][rx] = TILE_WALL
		grid[height - 1][rx] = TILE_WALL

	return {
		"grid": grid,
		"rooms": rooms,
		"width": width,
		"height": height,
		"seed": seed,
	}

## Split recursivo: divide el nodo solo si aun no alcanzamos target_leaves. (legacy)
static func _smart_split(node: BSPNode, target_leaves: int, rng: RandomNumberGenerator, leaves_out: Array) -> void:
	pass

## Conecta recursivamente las salas hijas del BSP via corredores en L.
static func _connect_rooms_bsp(node: BSPNode, grid: Array, rooms: Array) -> void:
	if node.is_leaf or node.left == null or node.right == null:
		return
	_connect_rooms_bsp(node.left, grid, rooms)
	_connect_rooms_bsp(node.right, grid, rooms)
	var lc: Vector2i = node.left.center()
	var rc: Vector2i = node.right.center()
	_carve_corridor_l(grid, lc, rc)

static func _carve_corridor_l(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var go_horizontal_first: bool = (a.x + a.y + b.x + b.y) % 2 == 0
	if go_horizontal_first:
		_carve_h(grid, a.x, b.x, a.y)
		_carve_v(grid, a.y, b.y, b.x)
	else:
		_carve_v(grid, a.y, b.y, a.x)
		_carve_h(grid, a.x, b.x, b.y)

static func _carve_h(grid: Array, x1: int, x2: int, y: int) -> void:
	var lo: int = min(x1, x2)
	var hi: int = max(x1, x2)
	for x in range(lo, hi + 1):
		if _in_bounds(grid, x, y):
			grid[y][x] = TILE_FLOOR

static func _carve_v(grid: Array, y1: int, y2: int, x: int) -> void:
	var lo: int = min(y1, y2)
	var hi: int = max(y1, y2)
	for y in range(lo, hi + 1):
		if _in_bounds(grid, x, y):
			grid[y][x] = TILE_FLOOR

static func _in_bounds(grid: Array, x: int, y: int) -> bool:
	return y >= 0 and y < grid.size() and x >= 0 and x < grid[0].size()