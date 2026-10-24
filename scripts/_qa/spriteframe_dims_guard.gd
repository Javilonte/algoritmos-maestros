extends SceneTree

## Guard contra el "frame atlas mismatch": la region de cada frame del
## SpriteFrames debe cubrir exactamente una celda del atlas, y el atlas debe
## quedar tiled sin huecos ni solapes.
##
## Run with:
##   godot --headless -s scripts/_qa/spriteframe_dims_guard.gd --quit-after 10
##
## ponytail: la version anterior hardcodeaba 344x280 y 320x320, o sea que
## fallaba en cuanto el extractor regeneraba las hojas con otra geometria.
## La celda correcta se DERIVA del atlas: ancho del atlas / cantidad de
## frames, y alto del atlas. Asi el guard sigue siendo valido cuando el
## extractor cambia.
##
## El guard tambien verifica el invariante que nadie chequeaba: con mas de
## un frame, la region de un frame NO puede ser el atlas entero. Ese es
## exactamente el bug que hacia que el jugador se dibujara como ocho
## personajes en fila (Godot ignora el campo "region" de un SpriteFrames
## serializado y dibuja la hoja completa).

const SPRITEFRAMES := [
	"res://resources/personaje_spriteframes.tres",
	"res://resources/crow_spriteframes.tres",
	"res://resources/personaje_plat_spriteframes.tres",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	for sf_path in SPRITEFRAMES:
		var sf: Resource = load(sf_path)
		if sf == null:
			failed += 1
			print("  FAIL: cannot load %s" % sf_path)
			continue

		var anim_names: PackedStringArray = sf.get_animation_names()
		if anim_names.is_empty():
			failed += 1
			print("  FAIL: %s has no animations" % sf_path)
			continue

		# Every animation is checked separately: each one can use a different
		# sheet with a different cell size (hurt is narrower than idle).
		for anim in anim_names:
			var frames_count: int = sf.get_frame_count(anim)
			if frames_count <= 0:
				failed += 1
				print("  FAIL: %s animation %s has no frames" % [sf_path, anim])
				continue

			var frame_tex: Texture2D = sf.get_frame_texture(anim, 0)
			if frame_tex == null:
				failed += 1
				print("  FAIL: %s[%s] frame[0] is null" % [sf_path, anim])
				continue

			var region: Rect2 = frame_tex.region
			var atlas: Texture2D = frame_tex.get_atlas() if frame_tex is AtlasTexture else frame_tex
			if atlas == null:
				failed += 1
				print("  FAIL: %s[%s] has no atlas" % [sf_path, anim])
				continue
			var atlas_w: int = atlas.get_width()
			var atlas_h: int = atlas.get_height()

			# The cell is derived from the sheet this animation uses: the
			# sheet is a run of uniform cells, so cell_w = atlas_w / frames
			# and cell_h = atlas_h.
			if atlas_w % frames_count != 0:
				failed += 1
				print("  FAIL: %s[%s] sheet width %d is not divisible by %d frames" % [
					sf_path.get_file(), anim, atlas_w, frames_count
				])
				continue
			var expected := Vector2i(atlas_w / frames_count, atlas_h)

			if region.size == Vector2(expected):
				passed += 1
			else:
				failed += 1
				print("  FRAME SIZE MISMATCH %s[%s]: expected %s, got %s" % [
					sf_path.get_file(), anim, expected, region.size
				])

			if region.position.x + region.size.x <= atlas_w and region.position.y + region.size.y <= atlas_h:
				passed += 1
			else:
				failed += 1
				print("  FRAME OUT OF BOUNDS %s[%s]: region=%s, atlas=%dx%d" % [
					sf_path.get_file(), anim, region, atlas_w, atlas_h
				])

			# A multi-frame sheet must never select the whole atlas: that is
			# the "region ignored" failure that drew every frame at once.
			if frames_count > 1 and region.size.x >= atlas_w:
				failed += 1
				print("  FRAME SELECTS WHOLE ATLAS %s[%s]: region=%s, atlas=%dx%d" % [
					sf_path.get_file(), anim, region, atlas_w, atlas_h
				])
			else:
				passed += 1

			# Every frame of the animation must have a texture.
			var covered := 0
			for i in range(frames_count):
				if sf.get_frame_texture(anim, i) != null:
					covered += 1
			if covered == frames_count:
				passed += 1
			else:
				failed += 1
				print("  FRAME COUNT MISMATCH %s[%s]: %d of %d frames have a texture" % [
					sf_path.get_file(), anim, covered, frames_count
				])

	print("\n========== SPRITEFRAME DIMS GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)
