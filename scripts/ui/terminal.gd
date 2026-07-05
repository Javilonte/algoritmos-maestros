## Terminal UI reutilizable. Usado por overworld (TerminalUI) y battle (BattleTerminal)
## vía composición. Ver `docs/UI_REFACTOR_PLAN.md` Fase 2.
##
## Esta clase provee la estructura visual y las properties exportadas.
## Las escenas `TerminalUI.tscn` y `battle_terminal.tscn` se convertirán en
## composiciones que instancian esta terminal con overrides.

class_name Terminal
extends Control


## Título que aparece en la TitleBar.
@export var title: String = "Terminal"

## Subtítulo opcional bajo el título (separador visual entre título y CodeEdit).
@export var subtitle: String = ""

## Texto del placeholder del CodeEdit.
@export var placeholder: String = "// Your code here..."

## Texto del botón submit. Override por contexto (e.g. "Submit Attack" en batalla).
@export var submit_label: String = "Submit"

## Si muestra botón Back. En batalla es false (controlado por battle state).
@export var show_back: bool = true

## Si añade Dimmer (overlay oscuro full screen) detrás del Panel.
@export var dimmer: bool = true

## Label de StatusBar visible (entre Panel y la consola). Usado por eventos de compilación.
@export var status_bar: bool = true

## Contexto para lógica derivada. Valores esperados: "overworld" | "battle".
@export var context: String = "overworld"


@onready var _dimmer: ColorRect = %Dimmer
@onready var _panel: Panel = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _progress: ProgressBar = %ProgressBar
@onready var _code_edit: CodeEdit = %CodeEdit
@onready var _console_output: RichTextLabel = %ConsoleOutput
@onready var _submit_button: Button = %SubmitButton
@onready var _back_button: Button = %BackButton


signal submitted()
signal back_pressed()


func _ready() -> void:
	_apply_text()
	_apply_visuals()
	_apply_initial_state()
	_submit_button.pressed.connect(_on_submit_pressed)
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)


func _apply_text() -> void:
	_title_label.text = title
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
	_code_edit.placeholder_text = placeholder
	_submit_button.text = submit_label


func _apply_visuals() -> void:
	UIStyle.apply_d2_panel(_panel)
	UIStyle.apply_d2_code_edit(_code_edit)
	UIStyle.apply_d2_button(_submit_button, "MD")
	if _back_button != null:
		UIStyle.apply_d2_button(_back_button, "SM")

	UIStyle.apply_d2_label(_title_label, UIResolve.Kind.GOLD_BRIGHT, UIResolve.Size.TITLE)
	UIStyle.apply_d2_label(_subtitle_label, UIResolve.Kind.MUTED, UIResolve.Size.LABEL)
	UIStyle.apply_d2_label(_status_label, UIResolve.Kind.MUTED, UIResolve.Size.LABEL)
	UIStyle.apply_d2_label(_console_output, UIResolve.Kind.BONE, UIResolve.Size.BODY)

	if _dimmer != null:
		_dimmer.color = D2Palette.SCREEN_OVERLAY
		_dimmer.visible = dimmer

	if _back_button != null:
		_back_button.visible = show_back


func _apply_initial_state() -> void:
	if _progress != null:
		_progress.visible = false
		_progress.value = 0.0
	if _status_label != null:
		_status_label.text = ""
		_status_label.visible = status_bar


## Muestra u oculta el progreso de compilación (0.0 a 1.0).
func set_progress(ratio: float) -> void:
	if _progress == null:
		return
	_progress.visible = ratio > 0.0 and ratio < 1.0
	_progress.value = clampf(ratio, 0.0, 1.0) * 100.0


## Escribe estado en StatusBar. Usado por eventos `compiling_*` y mensajes finales.
func set_status(text: String) -> void:
	if _status_label == null:
		return
	_status_label.text = text


## Reemplaza el contenido de la consola con texto BBCode.
func set_console(bbcode: String) -> void:
	if _console_output == null:
		return
	_console_output.text = bbcode


## Appendea una línea BBCode al final de la consola.
func append_console(bbcode: String) -> void:
	if _console_output == null:
		return
	_console_output.append_text(bbcode + "\n")


## Limpia y setea el código del editor (e.g. starter_code de un challenge).
func set_code(code: String) -> void:
	if _code_edit == null:
		return
	_code_edit.text = code


## Devuelve el código actual del editor.
func get_code() -> String:
	if _code_edit == null:
		return ""
	return _code_edit.text


## Bloquea o desbloquea el botón submit. Útil durante compilación.
func set_submit_locked(locked: bool) -> void:
	if _submit_button == null:
		return
	_submit_button.disabled = locked


func _on_submit_pressed() -> void:
	submitted.emit()


func _on_back_pressed() -> void:
	back_pressed.emit()
