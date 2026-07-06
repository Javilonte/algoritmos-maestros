extends SceneTree

## Lists the µFantasy assets in the project's external/ directory.
## Run: godot --headless -s scripts/_qa/microfantasy_inventory.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var base: String = "res://assets/external/microfantasy"
	print("\n========== µFANTASY INVENTORY ==========")
	if not DirAccess.open(base):
		print("  %s does not exist." % base)
		print("  Drop the microFantasy.v0.4.zip contents here.")
		quit(0)
		return
	_scan(base)
	print("=========================================\n")
	quit(0)


func _scan(path: String) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full: String = path + "/" + name
		if d.current_is_dir():
			print("  DIR  %s/" % full)
			_scan(full)
		else:
			var f: FileAccess = FileAccess.open(full, FileAccess.READ)
			var size: int = 0
			if f:
				f.seek_end()
				size = f.get_position()
				f.close()
			print("  FILE %s (%d bytes)" % [full, size])
		name = d.get_next()
	d.list_dir_end()
