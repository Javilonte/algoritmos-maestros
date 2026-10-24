extends SceneTree

# Builds the SpriteFrames resource for the crow enemy.
# 4 animations: idle, walk, attack, hurt.

const OUT_PATH := "res://resources/crow_spriteframes.tres"

const ATLASES := {
	"idle":    "res://assets/textures/crow_idle.png",
	"walk":    "res://assets/textures/crow_walk.png",
	"attack":  "res://assets/textures/crow_attack.png",
	"hurt":    "res://assets/textures/crow_hurt.png",
}
const FRAME_COUNTS := {
	"idle": 4,
	"walk": 7,
	"attack": 4,
	"hurt": 2,
}
const CELL_W := 320
const CELL_H := 320
# Crow FPS — slightly slower than player for a heavier feel.
const FPS := 6



func _init() -> void:
	var sf := SpriteFrames.new()
	# ponytail: SpriteFrames.new() ships with an empty "default" animation.
	# Nothing referenced it and it made the spriteframe dims guard fail on
	# an animation with zero frames.
	if sf.has_animation("default"):
		sf.remove_animation("default")

	for anim_name in ["idle", "walk", "attack", "hurt"]:
		var atlas_path: String = ATLASES[anim_name]
		var tex: Texture2D = load(atlas_path)
		if tex == null:
			push_error("Cannot load %s" % atlas_path)
			quit(1); return
		var count: int = FRAME_COUNTS[anim_name]
		# ponytail: the cell size is derived from the sheet instead of being
		# hardcoded. The extractor now re-anchors the crow into tight uniform
		# cells, so 320x320 no longer holds, and a hardcoded size silently
		# selects the wrong region of the sheet.
		var sheet_w: int = tex.get_width()
		var sheet_h: int = tex.get_height()
		if sheet_w % count != 0:
			push_error("%s width %d is not divisible by %d frames" % [atlas_path, sheet_w, count])
			quit(1); return
		var cell_w: int = sheet_w / count
		var cell_h: int = sheet_h
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, FPS)
		sf.set_animation_loop(anim_name, true)
		for i in range(count):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * cell_w, 0, cell_w, cell_h)
			sf.add_frame(anim_name, atlas)

	var err := ResourceSaver.save(sf, OUT_PATH)
	if err != OK:
		push_error("Failed to save %s: %d" % [OUT_PATH, err])
		quit(1); return
	print("Saved %s with %d animations" % [OUT_PATH, sf.get_animation_names().size()])
	quit(0)