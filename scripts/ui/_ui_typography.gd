## Helpers de tipografía. Implementación completa en Fase 6 (post-refactor).
## Por ahora solo expone firma placeholder; mantiene la API para no romper imports.

class_name UITypography


## Carga la fuente default del theme desde `res://assets/fonts/`
## y la asigna al theme root. No-op hasta Fase 6.
static func apply_default_font(_theme: Theme) -> void:
	pass


## Recorre un subárbol aplicando la fuente default. No-op hasta Fase 6.
static func apply_default_font_recursive(_node: Node) -> void:
	pass
