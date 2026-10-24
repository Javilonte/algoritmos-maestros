class_name CyberStyleBox

## Estilos neón para la interfaz cyberpunk.
##
## ponytail: la pantalla de combate usaba D2StyleBox, que es la paleta de
## Diablo II: bordes dorados sobre paneles de madera. Eso se lee "RPG
## fantasía", no "cyberpunk". Estos helpers dejan el look neón en un solo
## lugar y reutilizan los acentos que D2Palette ya declaraba
## (NEON_CYAN / NEON_MAGENTA) en vez de inventar una paleta nueva.
##
## ponytail: la pantalla de combate mezclaba las dos paletas — el texto del
## VS en dorado, el mensaje en BONE_TEXT, el relleno de HP en rojo D2. Aquí
## vive ahora TODO el color de esa pantalla: una sola fuente, cero D2.
##
## Ceiling: son StyleBoxFlat planos con borde. Sin degradados ni glow real:
## para el glow de verdad hace falta un shader, y el costo de un
## StyleBoxFlat es cero.

const CYAN := Color(0.0, 0.95, 0.85)
const MAGENTA := Color(0.95, 0.25, 0.95)
const AMBER := Color(0.98, 0.72, 0.20)
const GREEN := Color(0.30, 0.95, 0.50)
const RED := Color(0.95, 0.28, 0.24)
const STEEL := Color(0.55, 0.66, 0.74)
const TEXT := Color(0.87, 0.94, 0.97)
const TEXT_DIM := Color(0.42, 0.52, 0.60)
const DEEP := Color(0.02, 0.03, 0.06, 0.92)
const DEEPER := Color(0.01, 0.015, 0.03, 0.96)
## Fondo del editor de codigo: casi negro con un tinte verde, para que
## el campo del editor se separe del panel que lo contiene.
const EDITOR_BG := Color(0.020, 0.055, 0.045, 1.0)


## Color como texto BBCode. Los mensajes del terminal van con etiquetas
## de color y escribirlas a mano duplicaba la paleta.
static func hex(color: Color) -> String:
	return "#" + color.to_html(false)


## Fondo de pantalla completa: opaco. El mundo de al detras no debe
## transparentarse a traves de la pantalla de combate.
static func backdrop(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.008, 0.012, 0.028, 1.0)
	sb.border_color = accent.darkened(0.62)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb


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


## Carta de retrato: el marco exterior de la ficha de combate.
static func card(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.022, 0.045, 1.0)
	sb.border_color = accent.darkened(0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## Area de arte: fondo casi negro y una linea de piso abajo. Sin borde
## propio — un marco dentro del marco de la carta se leia como caja
## dentro de caja.
static func art_backdrop(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.006, 0.010, 0.022, 1.0)
	sb.border_color = accent.darkened(0.68)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(0)
	return sb


## Insignia circular del VS.
static func vs_badge() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.02, 0.14, 0.92)
	sb.border_color = MAGENTA
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(52)
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
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.95)
	sb.border_color = accent.darkened(0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 8.0
	return sb


## Barra horizontal: fondo oscuro y sin borde. El borde lo pone la
## tira neón que va pegada abajo.
static func bar(fill: Color = Color(0.010, 0.020, 0.040, 1.0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb


## Barra de pie: un pelo mas clara que el fondo, para que la banda se
## lea sin necesidad de un borde.
static func footer_bar() -> StyleBoxFlat:
	return bar(Color(0.018, 0.032, 0.055, 1.0))


## Tira neón: solo el borde inferior, que es la linea que separa la
## cabecera del cuerpo.
static func neon_strip(accent: Color = CYAN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = accent
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
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


## Editor de codigo: fondo casi negro y borde del acento. El fondo real
## del CodeEdit lo pinta su color de tema `background_color`, NO este
## stylebox — hay que cambiar los dos.
static func editor(accent: Color = GREEN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = EDITOR_BG
	sb.border_color = accent.darkened(0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 8.0
	return sb


## Relleno de barra con borde mas claro que el fondo.
static func fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.lightened(0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


## Rampa de vida: verde -> ambar -> rojo. Una barra de HP siempre roja
## no dice nada: el color ES la informacion.
static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return GREEN
	if ratio > 0.25:
		return AMBER
	return RED


## Punto de habilidad. El bloqueado tiene que verse: un punto oscuro
## sobre un fondo oscuro es un hueco, y el panel parecia vacio teniendo
## catorce ranuras.
static func dot(unlocked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if unlocked:
		sb.bg_color = CYAN
		sb.border_color = CYAN.lightened(0.2)
	else:
		sb.bg_color = Color(0.09, 0.12, 0.16, 1.0)
		sb.border_color = Color(0.26, 0.33, 0.40, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


## Separador horizontal entre secciones de un panel.
static func separator() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.24, 0.30, 1.0)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb
