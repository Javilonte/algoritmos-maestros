extends CanvasLayer
class_name TutorialOverlay

## Tutorial de una sola vez que aparece tras la primera batalla.
## Marca "tutorial_seen" en settings para no volver a mostrarse.

signal closed

const SETTINGS_KEY := "tutorial_seen"

@onready var outer_frame: Panel = $OuterFrame
@onready var inner_panel: Panel = $OuterFrame/InnerPanel
@onready var title_label: Label = $OuterFrame/InnerPanel/TitleLabel
@onready var body_label: RichTextLabel = $OuterFrame/InnerPanel/BodyLabel
@onready var next_button: Button = $OuterFrame/InnerPanel/ButtonRow/NextButton
@onready var skip_button: Button = $OuterFrame/InnerPanel/ButtonRow/SkipButton

var _panels: Array[Dictionary] = [
	{
		"title": "¡Bienvenido, Maestro del Código!",
		"body": "[color=#ebcb8b]Tu objetivo[/color]: derrotar monstruos escribiendo C++.\n\nLas barras rojas arriba son tu HP, las azules tu XP. El número dorado es tu nivel.",
	},
	{
		"title": "El Editor",
		"body": "Escribe código C++ en el editor. El linter debajo te avisa de errores en tiempo real.\n\nLa marca [color=#a3be8c]// OK[/color] indica que el código está listo.",
	},
	{
		"title": "Ataca con Código",
		"body": "Tienes [color=#ebcb8b]30 segundos[/color] por ronda. Pulsa [color=#a3be8c]Submit Attack[/color] antes de que el timer llegue a 0.\n\n[color=#88c0d0]Tip:[/color] cuanto más rápido, más daño haces.",
	},
]
var _index: int = 0

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_local_overrides()
	_show_panel()

func _apply_local_overrides() -> void:
	if outer_frame:
		outer_frame.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())
	if inner_panel:
		inner_panel.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
	if title_label:
		title_label.add_theme_font_size_override("font_size", UIMetrics.FONT_HERO)
	if body_label:
		body_label.add_theme_font_size_override("normal_font_size", UIMetrics.FONT_BODY + 1)
		body_label.add_theme_font_size_override("bold_font_size", UIMetrics.FONT_BODY_LARGE)
		body_label.add_theme_font_size_override("mono_font_size", UIMetrics.FONT_BODY + 1)
	if next_button:
		next_button.add_theme_font_size_override("font_size", UIMetrics.FONT_BODY)
	if skip_button:
		skip_button.add_theme_font_size_override("font_size", UIMetrics.FONT_BODY)

func _show_panel() -> void:
	var data: Dictionary = _panels[_index]
	title_label.text = data["title"]
	body_label.text = data["body"]
	next_button.text = "Siguiente" if _index < _panels.size() - 1 else "¡Listo!"

func _on_next_pressed() -> void:
	_index += 1
	if _index >= _panels.size():
		_close()
		return
	_show_panel()

func _on_skip_pressed() -> void:
	_close()

func _close() -> void:
	var settings := SaveManager.load_settings()
	settings[SETTINGS_KEY] = true
	SaveManager.save_settings(settings)
	closed.emit()
	queue_free()

static func should_show() -> bool:
	var settings := SaveManager.load_settings()
	return not bool(settings.get(SETTINGS_KEY, false))

static func show_if_needed(parent: Node) -> void:
	if not should_show():
		return
	var scene: PackedScene = load("res://scenes/ui/tutorial_overlay.tscn")
	var overlay := scene.instantiate() as TutorialOverlay
	if overlay == null:
		return
	parent.add_child(overlay)