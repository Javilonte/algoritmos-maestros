extends ColorRect

## IsoBackground — solid ColorRect that sits behind all TileMapLayers.
## Without this, the clear color of the main viewport leaks through and the
## world looks "floating on grey" outside the iso diamonds.
##
## Use `iso_forest_green` as the default; can be overridden per-scene.

class_name IsoBackground

@export var color_override: Color = Color(0.18, 0.30, 0.18, 1):
	set(value):
		color_override = value
		if self:
			color = value

func _ready() -> void:
	color = color_override
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE)
	z_index = -10