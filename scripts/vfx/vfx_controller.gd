extends Node
class_name VFXController

## Controlador central de efectos visuales y sonoros.
## Se conecta a un controller que emita `damage_applied` /
## `compilation_completed` y reproduce:
##   - Screen shake al impacto (daño > umbral).
##   - Partículas al compilar con éxito.
##   - Glitch overlay en errores de compilación.
##   - Sonido de tecleo mecánico (throttle 35ms).
##
## Restricción: los efectos visuales no afectan a la legibilidad del terminal.

signal impact_vfx_played(damage: int)
signal compile_vfx_played(success: bool)

@export var camera_path: NodePath
@export var shake_magnitude: float = 4.0
@export var shake_duration: float = 0.18
@export var shake_damage_threshold: int = 20
@export var key_clack_path: NodePath
@export var sfx_bus: String = "Master"

var _camera: Camera2D
var _key_clack: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _last_key_sound_ms: int = 0
var _shake_tween: Tween = null
var _particles: GPUParticles2D
var _glitch_overlay: ColorRect
var _glitch_shader: ShaderMaterial

func _ready() -> void:
	_rng.randomize()
	if camera_path != NodePath(""):
		_camera = get_node(camera_path) as Camera2D
	if key_clack_path != NodePath(""):
		_key_clack = get_node(key_clack_path) as AudioStreamPlayer
	_build_particles()
	_build_glitch_overlay()

## ponytail: previously took a CombatController parameter; that class is
## orphaned. The hook is still useful — VFXController can be bound to any
## object that emits damage_applied / compilation_completed.
func bind_to_controller(controller: Node) -> void:
	if controller == null:
		return
	if controller.has_signal("damage_applied"):
		controller.damage_applied.connect(_on_damage_applied)
	if controller.has_signal("compilation_completed"):
		controller.compilation_completed.connect(_on_compilation_completed)

func bind_to_terminal(terminal: Node) -> void:
	if terminal == null:
		return
	if terminal.has_signal("char_typed"):
		terminal.char_typed.connect(_on_char_typed)
	if terminal.has_signal("macro_used"):
		terminal.macro_used.connect(_on_char_typed)  # también suena

## --- Impact ---

func _on_damage_applied(amount: int, _hp_after: int, _breakdown: Dictionary) -> void:
	if amount >= shake_damage_threshold:
		shake()
	impact_vfx_played.emit(amount)

func shake() -> void:
	if _camera == null:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var base_offset := _camera.offset
	var t := create_tween()
	var steps := 12
	for i in range(steps):
		var off := base_offset + Vector2(
			_rng.randf_range(-shake_magnitude, shake_magnitude),
			_rng.randf_range(-shake_magnitude, shake_magnitude)
		)
		t.tween_property(_camera, "offset", off, shake_duration / float(steps))
	t.tween_property(_camera, "offset", base_offset, shake_duration / float(steps))
	_shake_tween = t

## --- Compile success ---

func _on_compilation_completed(result: Dictionary) -> void:
	var compiled := bool(result.get("compiled", false))
	if compiled:
		_play_impact_particles()
		compile_vfx_played.emit(true)
	else:
		_play_glitch()
		compile_vfx_played.emit(false)

func _build_particles() -> void:
	_particles = GPUParticles2D.new()
	_particles.amount = 24
	_particles.lifetime = 0.6
	_particles.one_shot = true
	_particles.emitting = false
	_particles.z_index = 5
	_particles.modulate = Color(0.4, 1.0, 0.7, 1.0)
	# process_material por código (no asset) para evitar dependencia externa.
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 100.0
	pm.gravity = Vector3(0, 80, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.6
	_particles.process_material = pm
	add_child(_particles)

func _play_impact_particles() -> void:
	if _particles == null:
		return
	_particles.restart()
	_particles.emitting = true

## --- Glitch ---

func _build_glitch_overlay() -> void:
	_glitch_overlay = ColorRect.new()
	_glitch_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_glitch_overlay.anchor_left = 0.0
	_glitch_overlay.anchor_top = 0.0
	_glitch_overlay.anchor_right = 1.0
	_glitch_overlay.anchor_bottom = 1.0
	_glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_overlay.z_index = 100
	_glitch_shader = ShaderMaterial.new()
	_glitch_shader.shader = _make_glitch_shader()
	_glitch_overlay.material = _glitch_shader
	# Lo añadimos a un CanvasLayer dedicado para no entorpecer el terminal.
	var cl := CanvasLayer.new()
	cl.layer = 50
	cl.add_child(_glitch_overlay)
	add_child(cl)

func _play_glitch() -> void:
	if _glitch_overlay == null:
		return
	_glitch_shader.set_shader_parameter("intensity", 0.0)
	var t := create_tween()
	t.tween_method(_set_glitch_intensity, 0.0, 0.6, 0.05)
	t.tween_method(_set_glitch_intensity, 0.6, 0.0, 0.3)

func _set_glitch_intensity(v: float) -> void:
	_glitch_shader.set_shader_parameter("intensity", v)
	_glitch_overlay.color = Color(0.2, 1.0, 0.4, v * 0.35)

func _make_glitch_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 uv = UV;
	float block_y = floor(uv.y * 40.0);
	float shift = sin(block_y * 12.9898) * intensity * 0.05;
	uv.x += shift;
	vec3 col = texture(screen_tex, uv).rgb;
	float band = step(0.5, fract(uv.y * 50.0 + TIME * 4.0));
	col.r += intensity * 0.2 * band;
	col.b -= intensity * 0.15 * band;
	COLOR = vec4(col, intensity * 0.35);
}
"""
	return s

## --- Keyboard audio ---

func _on_char_typed(_ch: String) -> void:
	if _key_clack == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_key_sound_ms < 35:
		return
	_last_key_sound_ms = now
	_key_clack.pitch_scale = _rng.randf_range(0.9, 1.1)
	_key_clack.bus = sfx_bus
	_key_clack.play()