extends Node

const SAVE_PATH: String = "user://savegame.json"
const SETTINGS_PATH: String = "user://settings.json"

func save_game(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json: Variant = JSON.parse_string(text)
	if json is Dictionary:
		return json as Dictionary
	return {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func save_settings(data: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return _default_settings()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return _default_settings()
	var text := file.get_as_text()
	file.close()
	var json: Variant = JSON.parse_string(text)
	if json is Dictionary:
		return json as Dictionary
	return _default_settings()

func _default_settings() -> Dictionary:
	return {
		"fullscreen": false,
		"volume": 80,
	}
