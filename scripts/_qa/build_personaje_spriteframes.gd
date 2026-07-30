extends SceneTree

# Builds a SpriteFrames resource for the cyberpunk character with
# 4 animations: idle, walk, interact, hurt.
#
# Each frame is an AtlasTexture into the corresponding atlas PNG.
# Frame size: 344x320 (each cell in the source atlas is 344 wide).

const OUT_PATH := "res://resources/personaje_spriteframes.tres"

const ATLASES := {
	"idle":    "res://assets/textures/personaje_idle.png",
	"walk":    "res://assets/textures/personaje_walk.png",
	"interact": "res://assets/textures/personaje_interact.png",
	"hurt":    "res://assets/textures/personaje_hurt.png",
}
const FRAME_COUNTS := {
	"idle": 8,
	"walk": 8,
	"interact": 4,
	"hurt": 4,
}
const CELL_W := 344
const CELL_H := 280  # ponytail: real atlas rows are 280 tall (was 320 — caused vertical frame shift)
const FPS := 8


func _init() -> void:
	var sf := SpriteFrames.new()

	for anim_name in ["idle", "walk", "interact", "hurt"]:
		var atlas_path: String = ATLASES[anim_name]
		var tex: Texture2D = load(atlas_path)
		if tex == null:
			push_error("Cannot load %s" % atlas_path)
			quit(1); return
		var count: int = FRAME_COUNTS[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, FPS)
		sf.set_animation_loop(anim_name, true)
		for i in range(count):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * CELL_W, 0, CELL_W, CELL_H)
			sf.add_frame(anim_name, atlas)

	var err := ResourceSaver.save(sf, OUT_PATH)
	if err != OK:
		push_error("Failed to save %s: %d" % [OUT_PATH, err])
		quit(1); return
	print("Saved %s with %d animations" % [OUT_PATH, sf.get_animation_names().size()])
	quit(0)