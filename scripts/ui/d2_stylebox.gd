class_name D2StyleBox

## Factory de StyleBoxFlat estilo Diablo II (minimalista).
## Sin assets externos: todo procedural con border colors + content_margin + corner_radius.
##
## Para el efecto bisel (light top-left + dark bottom-right), StyleBoxFlat no soporta
## bordes por lado. Solución: dos Panels anidados (outer bronce + inner stone oscuro).
## Las funciones `panel_bronze_*` devuelven el outer; el caller debe añadir un Panel
## hijo con `panel_inner()` para completar el bisel.

const CONTENT_MARGIN_H := 8.0
const CONTENT_MARGIN_V := 6.0
const CORNER_RADIUS := 2

## Panel exterior con borde bronce sólido. Usar como wrapper de un Panel interior.
static func panel_bronze() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.BRONZE_DARK
	sb.border_color = D2Palette.BRONZE_LIGHT
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = CORNER_RADIUS
	sb.corner_radius_top_right = CORNER_RADIUS
	sb.corner_radius_bottom_right = CORNER_RADIUS
	sb.corner_radius_bottom_left = CORNER_RADIUS
	sb.corner_detail = 4
	sb.content_margin_left = CONTENT_MARGIN_H
	sb.content_margin_top = CONTENT_MARGIN_V
	sb.content_margin_right = CONTENT_MARGIN_H
	sb.content_margin_bottom = CONTENT_MARGIN_V
	return sb

## Panel interior (sunken). Para usar dentro de un panel_bronze como segundo nivel.
static func panel_inner() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.STONE_DARK
	sb.border_color = D2Palette.STONE_HIGHLIGHT
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 1
	sb.corner_radius_top_right = 1
	sb.corner_radius_bottom_right = 1
	sb.corner_radius_bottom_left = 1
	sb.content_margin_left = CONTENT_MARGIN_H
	sb.content_margin_top = CONTENT_MARGIN_V
	sb.content_margin_right = CONTENT_MARGIN_H
	sb.content_margin_bottom = CONTENT_MARGIN_V
	return sb

## Panel de fondo genérico para pantallas (stone oscuro plano).
static func panel_screen_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.STONE_DARK
	return sb

## Fondo de barra de progreso (sunken stone).
static func bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.02)
	sb.border_color = D2Palette.STONE_HIGHLIGHT
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 1
	sb.corner_radius_top_right = 1
	sb.corner_radius_bottom_right = 1
	sb.corner_radius_bottom_left = 1
	sb.content_margin_left = 1.0
	sb.content_margin_top = 1.0
	sb.content_margin_right = 1.0
	sb.content_margin_bottom = 1.0
	return sb

## Fill de barra (color liso con borde interno).
static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.lightened(0.25)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 1
	sb.corner_radius_top_right = 1
	sb.corner_radius_bottom_right = 1
	sb.corner_radius_bottom_left = 1
	return sb

## Botón en estado normal (stone con borde bronce).
static func button_normal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.STONE_MID
	sb.border_color = D2Palette.BRONZE_MID
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = CORNER_RADIUS
	sb.corner_radius_top_right = CORNER_RADIUS
	sb.corner_radius_bottom_right = CORNER_RADIUS
	sb.corner_radius_bottom_left = CORNER_RADIUS
	sb.content_margin_left = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 6.0
	return sb

## Botón hover (más claro, borde bronce highlight).
static func button_hover() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.STONE_LIGHT
	sb.border_color = D2Palette.BRONZE_HI
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = CORNER_RADIUS
	sb.corner_radius_top_right = CORNER_RADIUS
	sb.corner_radius_bottom_right = CORNER_RADIUS
	sb.corner_radius_bottom_left = CORNER_RADIUS
	sb.content_margin_left = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 6.0
	return sb

## Botón presionado (más oscuro, bordes invertidos).
static func button_pressed() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.STONE_DARK
	sb.border_color = D2Palette.BRONZE_DARK
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = CORNER_RADIUS
	sb.corner_radius_top_right = CORNER_RADIUS
	sb.corner_radius_bottom_right = CORNER_RADIUS
	sb.corner_radius_bottom_left = CORNER_RADIUS
	sb.content_margin_left = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 6.0
	return sb

## Botón deshabilitado.
static func button_disabled() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.STONE_MID
	sb.border_color = D2Palette.STONE_HIGHLIGHT
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 1
	sb.corner_radius_top_right = 1
	sb.corner_radius_bottom_right = 1
	sb.corner_radius_bottom_left = 1
	sb.content_margin_left = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 6.0
	return sb

## Panel estilo editor (sunken muy oscuro).
static func code_inner() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.02)
	sb.border_color = D2Palette.BRONZE_DARK
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_bottom = 4.0
	return sb

## Slot/sigil donde se aloja un sprite (cuadrado con marco).
static func sigil() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.02, 0.6)
	sb.border_color = D2Palette.BRONZE_MID
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_right = 2
	sb.corner_radius_bottom_left = 2
	sb.content_margin_left = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_bottom = 4.0
	return sb

## Pequeño sigil cuadrado para el nivel del personaje.
static func sigil_small() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = D2Palette.STONE_DARK
	sb.border_color = D2Palette.BRONZE_LIGHT
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_right = 2
	sb.corner_radius_bottom_left = 2
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb