class_name ValidationResultFormatter
extends RefCounted

static func format_line(result: Dictionary, success_prefix: String = "", fail_prefix: String = "") -> String:
	if result.success:
		return "[color=green]>> %s%s[/color]" % [success_prefix, result.message]
	return "[color=red]>> %s%s[/color]" % [fail_prefix, result.message]
