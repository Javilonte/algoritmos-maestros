class_name CyberStyleBox

## Estilos neón para la interfaz cyberpunk.
##
## ponytail: la pantalla de combate usaba D2StyleBox, que es la paleta de
## Diablo II: bordes dorados sobre paneles de madera. Eso se lee "RPG
## fantasía", no "cyberpunk". Estos helpers dejan el look neón en un solo
## lugar y reutilizan los acentos que D2Palette ya declaraba
## (NEON_CYAN / NEON_MAGENTA) en vez de inventar una paleta nueva.
##
## Ceiling: son StyleBoxFlat planos con borde. Sin degradados ni glow real:
## para el glow de verdad hace falta un shader, y el costo de un
## StyleBoxFlat es cero.

const CYAN := Color(0.0, 0.95, 0.85)
const MAGENTA := Color(0.95, 0.25, 0.95)
const DEEP := Color(0.02, 0.03, 0.06, 0.92)
const DEEPER := Color(0.01, 0.015, 0.03, 0.96)


## Panel principal: fondo casi negro azulado con borde neón.
static func panel(accent: Color = CYAN, fill: Color = DEEP) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 10.0
	return sb


## Marco de retrato: borde doble, la linea interior mas tenue.
static func frame(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DEEPER
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 8.0
	return sb


## Insignia circular del VS.
static func vs_badge() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.02, 0.14, 0.92)
	sb.border_color = MAGENTA
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(50)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb


## Boton de accion en reposo.
static func button(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.09, 0.95)
	sb.border_color = accent.darkened(0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 18.0
	sb.content_margin_bottom = 10.0
	return sb


## Boton de accion al pasar el mouse.
static func button_hover(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := button(accent)
	sb.bg_color = Color(0.05, 0.14, 0.16, 0.98)
	sb.border_color = accent
	return sb


## Boton de accion presionado.
static func button_pressed(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := button(accent)
	sb.bg_color = accent.darkened(0.6)
	sb.border_color = accent
	return sb


## Chip compacto: contador de tiempo, etiquetas sueltas.
static func chip(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.9)
	sb.border_color = accent.darkened(0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 4.0
	return sb


## Canal de barra: mas claro que el fondo casi negro de D2StyleBox, para que
## una barra vacia se lea como una barra y no como un hole.
static func track() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.16, 1.0)
	sb.border_color = Color(0.26, 0.28, 0.36, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


## Relleno de barra con borde mas claro que el fondo.
static func fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.lightened(0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb
