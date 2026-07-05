## Helpers para resolver colores, tamaños y BBCode de la UI usando
## `D2Palette` y `UIMetrics` como fuente única de verdad.
##
## Uso: `var c = UIStyle.label_color(UIStyle.Kind.TITLE)` o
##      `var text = UIStyle.bbcode_status(UIStyle.Level.OK, "Compile finished")`.

class_name UIResolve

enum Kind {
	GOLD,
	GOLD_BRIGHT,
	BONE,
	MUTED,
	DANGER,
}

enum Size {
	LABEL,
	BODY,
	BODY_LARGE,
	TITLE,
	HERO,
	DISPLAY,
	CODE,
}

enum Level {
	OK,
	INFO,
	WARN,
	ERR,
	HINT,
}


static func label_color(kind: Kind) -> Color:
	match kind:
		Kind.GOLD: return D2Palette.GOLD_TEXT
		Kind.GOLD_BRIGHT: return D2Palette.GOLD_TEXT_BRIGHT
		Kind.BONE: return D2Palette.BONE_TEXT
		Kind.MUTED: return D2Palette.MUTED_TEXT
		Kind.DANGER: return D2Palette.DANGER_TEXT
	return D2Palette.BONE_TEXT


static func label_size(size: Size) -> int:
	match size:
		Size.LABEL: return UIMetrics.FONT_LABEL
		Size.BODY: return UIMetrics.FONT_BODY
		Size.BODY_LARGE: return UIMetrics.FONT_BODY_LARGE
		Size.TITLE: return UIMetrics.FONT_TITLE
		Size.HERO: return UIMetrics.FONT_HERO
		Size.DISPLAY: return UIMetrics.FONT_DISPLAY
		Size.CODE: return UIMetrics.FONT_CODE
	return UIMetrics.FONT_BODY


## Genera un fragmento BBCode con prefijo de estado coloreado.
## Ej: `bbcode_status(Level.OK, "Compile finished")` →
##     `"[color=#ebc880][OK][/color] Compile finished"`
static func bbcode_status(level: Level, text: String) -> String:
	var prefix: String
	var color: Color
	match level:
		Level.OK:
			prefix = "[OK]"
			color = D2Palette.GOLD_TEXT_BRIGHT
		Level.INFO:
			prefix = "[INFO]"
			color = D2Palette.BONE_TEXT
		Level.WARN:
			prefix = "[WARN]"
			color = D2Palette.BRONZE_HI
		Level.ERR:
			prefix = "[ERR]"
			color = D2Palette.DANGER_TEXT
		Level.HINT:
			prefix = "[HINT]"
			color = D2Palette.BRONZE_LIGHT
	return "[color=#%s]%s[/color] %s" % [color.to_html(false), prefix, text]
