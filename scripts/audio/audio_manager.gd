extends Node
class_name AudioManager

## Gestor de audio del juego. Centraliza la reproducción de SFX y música.
## Usa un bus "SFX" independiente para no chocar con la música.

const BUS_SFX: String = "SFX"
const BUS_MUSIC: String = "Music"

@export var sfx_volume_db: float = -6.0
@export var music_volume_db: float = -10.0

var _key_clack: AudioStream
var _hit_success: AudioStream
var _hit_fail: AudioStream

func _ready() -> void:
	_ensure_bus(BUS_SFX, sfx_volume_db)
	_ensure_bus(BUS_MUSIC, music_volume_db)
	# Carga de streams procedurales (no requiere assets externos).
	_key_clack = _make_key_clack()
	_hit_success = _make_hit(true)
	_hit_fail = _make_hit(false)

func _ensure_bus(bus_name: String, vol_db: float) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), vol_db)

func get_key_clack() -> AudioStream:
	return _key_clack

func get_hit(success: bool) -> AudioStream:
	return _hit_success if success else _hit_fail

## --- Procedural audio (no requiere archivos) ---

func _make_key_clack() -> AudioStream:
	var sample_rate := 22050
	var duration := 0.08
	var frames := int(sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.mix_rate = sample_rate
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.stereo = false
	var data := PackedByteArray()
	data.resize(frames)
	for i in range(frames):
		var t := float(i) / sample_rate
		var env := exp(-t * 60.0)
		var noise := randf() * 2.0 - 1.0
		var click := sin(t * 1500.0) * 0.4
		var v := clampf((click + noise * 0.6) * env, -1.0, 1.0)
		data[i] = int((v * 0.5 + 0.5) * 255.0)
	audio.data = data
	return audio

func _make_hit(success: bool) -> AudioStream:
	var sample_rate := 22050
	var duration := 0.25
	var frames := int(sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.mix_rate = sample_rate
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.stereo = false
	var data := PackedByteArray()
	data.resize(frames)
	var freq := 880.0 if success else 220.0
	for i in range(frames):
		var t := float(i) / sample_rate
		var env := exp(-t * 6.0) if success else exp(-t * 12.0)
		var wave := sin(t * freq * TAU)
		var v := clampf(wave * env * 0.7, -1.0, 1.0)
		data[i] = int((v * 0.5 + 0.5) * 255.0)
	audio.data = data
	return audio
