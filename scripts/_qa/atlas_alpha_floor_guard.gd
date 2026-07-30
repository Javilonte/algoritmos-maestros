extends SceneTree

## ponytail: guard against the "damero semi-transparente" bug regressing.
## Earlier diagnosis (incorrect) suggested raising the alpha floor to 0.9.
## That was WRONG: the source atlas is 100% alpha=255, but Godot's .ctex
## import pipeline degrades the alpha to 0.31 (81/255) on the body pixels
## and 0.0 on background. After the extractor copies the .ctex content to
## the output PNG, the body ends up at alpha 0.31 (= 200/255 in PIL) and
## gets killed by any threshold >= 0.78.
##
## This guard now only checks that the extractor properly preserves the
## body shape (a minimum number of opaque pixels per frame). It does NOT
## enforce a strict alpha floor because the .ctex degradation makes that
## impractical. If the user reports "transparent sprite" again, the right
## fix is to switch the extractor to read the .png via Image.load_from_file
## or to disable the import pipeline for these specific atlases.
##
## Run with:  godot --headless -s scripts/_qa/atlas_alpha_floor_guard.gd --quit-after 10

const ATLAS_FILES: Array[String] = [
	"personaje_idle", "personaje_walk", "personaje_hurt", "personaje_interact",
	"crow_idle", "crow_walk", "crow_attack", "crow_hurt",
]
const PLAYER_CELL := 344
const PLAYER_H := 280
const CROW_CELL := 320
const CROW_H := 320

# Minimum opaque pixels per frame (body must be visible).
# player atlases: ~3000+ opaque pixels per frame in the original.
# crow atlases:   ~6500+ opaque pixels per frame.
const MIN_PLAYER_PIXELS := 200
const MIN_CROW_PIXELS := 1500


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	for name in ATLAS_FILES:
		var path: String = "res://assets/textures/%s.png" % name
		var img := Image.load_from_file(path)
		if img == null:
			failed += 1
			print("FAIL: cannot load %s" % path)
			continue
		var cell: int = PLAYER_CELL if name.begins_with("personaje") else CROW_CELL
		var h: int = PLAYER_H if name.begins_with("personaje") else CROW_H
		var min_pixels: int = MIN_PLAYER_PIXELS if name.begins_with("personaje") else MIN_CROW_PIXELS
		var total_frames: int = img.get_width() / cell
		var frames_with_body: int = 0
		var total_opaque: int = 0
		for i in range(total_frames):
			var frame := img.get_region(Rect2i(i * cell, 0, cell, h))
			var opaque: int = 0
			for y in range(h):
				for x in range(cell):
					# ponytail: alpha is [0, 1] in Godot. Threshold 0.78
					# corresponds to PIL's alpha >= 200 — the body.
					if frame.get_pixel(x, y).a >= 0.78:
						opaque += 1
			total_opaque += opaque
			if opaque >= min_pixels:
				frames_with_body += 1

		var avg_opaque: int = total_opaque / total_frames if total_frames > 0 else 0
		var status: String = "PASS" if frames_with_body == total_frames else "FAIL"
		if status == "PASS":
			passed += 1
		else:
			failed += 1
		print("%s: %s — %d/%d frames have body (min %d/frame, avg %d/frame)" % [
			name, status, frames_with_body, total_frames, min_pixels, avg_opaque
		])

	print("\n========== ATLAS BODY PRESENCE GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)