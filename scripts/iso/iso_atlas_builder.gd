extends Node

## IsoAtlasBuilder — singleton autoload que extiende el atlas isométrico.
##
## Mantiene TRES texturas cargadas:
##   - ORIGINAL: assets/textures/practice_iso_tiles_original.png (350x112, 14 tiles,
##                incluye el sprite del personaje teal). NO se modifica.
##   - EXTENDED: assets/textures/iso_terrain_atlas.png (350x784, 98 tiles,
##                fallback procedural si falta).
##   - MICRPFANTASY: assets/external/microfantasy/iso/iso_tileset.png (288x160,
##                18x20 grid de tiles retro 8-bit del set "µFantasy" de 0x72, CC0).
##                Si falta, se cae al procedural sin error.
##
## Acceso global:
##   IsoAtlasBuilder.original_texture
##   IsoAtlasBuilder.extended_texture
##   IsoAtlasBuilder.microfantasy_texture
##   IsoAtlasBuilder.knight_sprite_texture   (knight_blue.png frames: 4 idle)
##   IsoAtlasBuilder.is_ready()
##   IsoAtlasBuilder.has_microfantasy()      (true if µFantasy assets exist)

const ORIGINAL_PATH := "res://assets/textures/practice_iso_tiles_original.png"
const EXTENDED_PATH := "res://assets/textures/iso_terrain_atlas.png"
const MICROFANTASY_ISO_PATH := "res://assets/external/microfantasy/iso/iso_tileset.png"
const MICROFANTASY_KNIGHT_PATH := "res://assets/external/microfantasy/characters/knight_blue.png"

const ATLAS_W: int = 350
const ATLAS_H_EXT: int = 784
const ATLAS_W_ORIG: int = 350
const ATLAS_H_ORIG: int = 112

const TILE_W: int = 50
const TILE_H: int = 56
const COLS: int = 7
const ROWS_TOTAL: int = 14

# µFantasy iso tile dimensions (source size)
const MF_TILE_W: int = 16
const MF_TILE_H: int = 8
const MF_COLS: int = 18
const MF_ROWS: int = 20

# µFantasy knight_blue: 4 frames horizontal, 24x32 per frame (full body w/ legs)
const KNIGHT_FRAME_W: int = 24
const KNIGHT_FRAME_H: int = 32
const KNIGHT_FRAME_COUNT: int = 4

const TERRAIN_ROW_GRASS_AUTO: int = 4
const TERRAIN_ROW_SAND_AUTO: int = 5
const TERRAIN_ROW_WATER_AUTO: int = 6
const DECOR_ROW_PROPS: int = 7

signal atlas_ready(original: Texture2D, extended: Texture2D)

var _is_ready: bool = false
var original_texture: Texture2D = null
var extended_texture: Texture2D = null
var microfantasy_texture: Texture2D = null
var knight_sprite_texture: Texture2D = null


func _ready() -> void:
	_build()


func _build() -> void:
	original_texture = _load_or_generate(ORIGINAL_PATH, ATLAS_W_ORIG, ATLAS_H_ORIG, false)
	extended_texture = _load_or_generate(EXTENDED_PATH, ATLAS_W, ATLAS_H_EXT, true)
	microfantasy_texture = _try_load_external(MICROFANTASY_ISO_PATH)
	knight_sprite_texture = _try_load_external(MICROFANTASY_KNIGHT_PATH)
	_is_ready = original_texture != null and extended_texture != null
	if _is_ready:
		atlas_ready.emit(original_texture, extended_texture)


func _try_load_external(path: String) -> Texture2D:
	## Loads a CC0 / external asset, returns null if missing (no error).
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res
	return null


func has_microfantasy() -> bool:
	return microfantasy_texture != null and knight_sprite_texture != null


## Returns the µFantasy iso tile texture, or null if not loaded.
func get_microfantasy_iso() -> Texture2D:
	return microfantasy_texture


## Returns the knight_blue sprite sheet, or null if not loaded.
func get_knight_sprite() -> Texture2D:
	return knight_sprite_texture


## Tile coord → µFantasy atlas (col, row) for common biomes.
## Returns atlas coord inside the µFantasy iso_tileset.png (MF_TILE_W × MF_TILE_H).
static func microfantasy_tile(biome: StringName, variant: int = 0) -> Vector2i:
	## Per the µFantasy docs the iso grid is 18 cols x 20 rows.
	## The exact row mapping is inferred from the placeholder; when the real
	## asset arrives, callers may override these targets in iso_meta.gd.
	match biome:
		&"grass":
			return Vector2i(variant % MF_COLS, 1)
		&"water":
			return Vector2i(variant % MF_COLS, 2)
		&"sand":
			return Vector2i(variant % MF_COLS, 4)
		&"path":
			return Vector2i(variant % MF_COLS, 6)
		&"tree":
			return Vector2i(variant % MF_COLS, 10)
		&"rock":
			return Vector2i(variant % MF_COLS, 8)
	return Vector2i(0, 1)


## Translate a µFantasy iso tile (col, row) into a scaled AtlasTexture suitable
## for an IsoPlayer Sprite2D node. Returns null if µFantasy isn't available.
func get_knight_frame_atlas(frame: int, scale: float = 3.0) -> AtlasTexture:
	if knight_sprite_texture == null:
		return null
	if frame < 0 or frame >= KNIGHT_FRAME_COUNT:
		frame = 0
	var atlas := AtlasTexture.new()
	atlas.atlas = knight_sprite_texture
	atlas.region = Rect2(frame * KNIGHT_FRAME_W, 0, KNIGHT_FRAME_W, KNIGHT_FRAME_H)
	return atlas


func _load_or_generate(path: String, w: int, h: int, is_extended: bool) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	if not is_extended:
		push_error("IsoAtlasBuilder: original atlas missing at %s" % path)
		return null
	# Generate procedurally.
	var gen := _ProceduralAtlasGenerator.new(w, h)
	var generated := gen.generate()
	if generated == null:
		push_error("IsoAtlasBuilder: procedural generation failed")
		return null
	generated.save_png(path)
	# Tell the resource cache that a new file exists, then load again.
	ResourceLoader.load(path)
	return ImageTexture.create_from_image(generated)


func is_ready() -> bool:
	return _is_ready


## Returns the biome autotile source row index for a given biome name.
static func terrain_row_for_biome(biome: StringName) -> int:
	match biome:
		&"grass": return TERRAIN_ROW_GRASS_AUTO
		&"sand": return TERRAIN_ROW_SAND_AUTO
		&"water": return TERRAIN_ROW_WATER_AUTO
	return TERRAIN_ROW_GRASS_AUTO


## Returns the atlas coord (col, row) for the first available tile of a biome.
static func biome_tile_origin(biome: StringName) -> Vector2i:
	var row := terrain_row_for_biome(biome)
	return Vector2i(0, row)


class _ProceduralAtlasGenerator:
	## Generates the extended atlas image procedurally.
	## Pure helpers — no I/O.
	var atlas_w: int
	var atlas_h: int
	var _img: Image
	var _rng: RandomNumberGenerator

	func _init(w: int, h: int) -> void:
		atlas_w = w
		atlas_h = h
		_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_rng = RandomNumberGenerator.new()
		_rng.seed = 424242

	func generate() -> Image:
		for ty in _rows_count():
			for tx in COLS:
				_paint_cell(tx, ty)
		return _img

	func _rows_count() -> int:
		return int(atlas_h / TILE_H)

	func _paint_cell(col: int, row: int) -> void:
		var fn: Callable
		match row:
			0, 1:
				fn = _legacy_passthrough
			2:
				fn = _gen_sand
			3:
				fn = _gen_water
			4, 5:
				fn = _gen_grass_top
			6:
				fn = _gen_water_with_foam
			7:
				fn = _prop_func_for_col(col)
			_:
				fn = _gen_placeholder
		var base_x: int = col * TILE_W
		var base_y: int = row * TILE_H
		for y in TILE_H:
			for x in TILE_W:
				var px: Color = fn.call(x, y, col, row)
				_img.set_pixel(base_x + x, base_y + y, px)

	# ---------- generators ----------
	func _in_iso_diamond(x: int, y: int) -> bool:
		var cx: float = float(TILE_W) / 2.0
		var cy: float = float(TILE_H) / 2.0
		var dx: float = abs(float(x) - cx) / (float(TILE_W) / 2.0 - 1.0)
		var dy: float = abs(float(y) - cy) / (float(TILE_H) / 2.0 - 1.0)
		return dx + dy <= 1.0

	func _legacy_passthrough(_x: int, _y: int, _c: int, _r: int) -> Color:
		return Color(0, 0, 0, 0)

	func _gen_grass_top(x: int, y: int, _c: int, _r: int) -> Color:
		if not _in_iso_diamond(x, y):
			return Color(0, 0, 0, 0)
		var t: float = float(y) / float(TILE_H - 1)
		var r: float = lerp(106.0, 80.0, t)
		var g: float = lerp(190.0, 160.0, t)
		var b: float = lerp(48.0, 38.0, t)
		return Color8(int(r), int(g), int(b), 255)

	func _gen_sand(x: int, y: int, _c: int, _r: int) -> Color:
		if not _in_iso_diamond(x, y):
			return Color(0, 0, 0, 0)
		var t: float = float(y) / float(TILE_H - 1)
		var r: float = lerp(230.0, 200.0, t)
		var g: float = lerp(210.0, 170.0, t)
		var b: float = lerp(140.0, 110.0, t)
		if (x * 13 + y * 7) % 11 == 0:
			r = max(0.0, r - 20); g = max(0.0, g - 20); b = max(0.0, b - 20)
		return Color8(int(r), int(g), int(b), 255)

	func _gen_water(x: int, y: int, _c: int, _r: int) -> Color:
		if not _in_iso_diamond(x, y):
			return Color(0, 0, 0, 0)
		var t: float = float(y) / float(TILE_H - 1)
		var r: float = lerp(60.0, 25.0, t)
		var g: float = lerp(115.0, 75.0, t)
		var b: float = lerp(200.0, 170.0, t)
		return Color8(int(r), int(g), int(b), 255)

	func _gen_water_with_foam(x: int, y: int, c: int, r: int) -> Color:
		var base := _gen_water(x, y, c, r)
		if base.a < 0.5:
			return base
		# Foam marker: thin line near top for cells 0, 6 and bottom for cell 3
		if c == 0 and y < 8:
			return Color8(230, 240, 250, 255)
		if c == 3 and y > TILE_H - 8:
			return Color8(230, 240, 250, 255)
		if c == 6 and y < 8:
			return Color8(230, 240, 250, 255)
		return base

	func _gen_tree(x: int, y: int, _c: int, _r: int) -> Color:
		if not _in_iso_diamond(x, y):
			return Color(0, 0, 0, 0)
		if y < int(TILE_H * 0.45):
			return Color8(60, 140, 70, 255)
		elif y < int(TILE_H * 0.65):
			return Color8(45, 110, 55, 255)
		else:
			return Color8(80, 50, 30, 255)

	func _gen_rock(x: int, y: int, _c: int, _r: int) -> Color:
		var cx: float = float(TILE_W) / 2.0
		var cy: float = float(TILE_H) / 2.0 + 5.0
		var r: float = abs(x - cx) + abs(y - cy) * 1.4
		if r > 18.0:
			return Color(0, 0, 0, 0)
		var grey: float = clamp(150.0 - r * 3.0, 80.0, 200.0)
		return Color8(int(grey + 20), int(grey), int(grey + 20), 255)

	func _gen_bush(x: int, y: int, _c: int, _r: int) -> Color:
		var cx: float = float(TILE_W) / 2.0
		var cy: float = float(TILE_H) / 2.0 + 4.0
		var r: float = abs(x - cx) + abs(y - cy) * 1.6
		if r > 16.0:
			return Color(0, 0, 0, 0)
		return Color8(90, 170, 80, 255)

	func _gen_flower(rgb: Color) -> Callable:
		return func(x: int, y: int, _c: int, _r: int) -> Color:
			var cx: float = float(TILE_W) / 2.0
			var cy: float = float(TILE_H) / 2.0 + 4.0
			var r: float = abs(x - cx) + abs(y - cy) * 1.6
			if r > 10.0:
				return Color(0, 0, 0, 0)
			if r > 7.0:
				return Color8(60, 140, 60, 255)
			return Color8(int(rgb.r * 255), int(rgb.g * 255), int(rgb.b * 255), 255)

	func _prop_func_for_col(col: int) -> Callable:
		match col:
			0: return _gen_tree
			1: return _gen_rock
			2: return _gen_bush
			3: return _gen_flower(Color(0.85, 0.18, 0.25))
			4: return _gen_flower(Color(0.95, 0.86, 0.25))
			5: return _gen_flower(Color(0.70, 0.40, 0.80))
			6: return _gen_rock
		return _gen_bush

	func _gen_placeholder(x: int, y: int, c: int, r: int) -> Color:
		var checker: bool = (c + r) % 2 == 0
		var col: Color = Color8(255, 0, 255, 255) if checker else Color8(40, 40, 40, 255)
		# small X marker
		var size := int(min(TILE_W, TILE_H))
		if x == y or x == size - 1 - y:
			col = Color8(255, 255, 255, 255)
		return col
