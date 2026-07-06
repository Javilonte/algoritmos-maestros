extends Control

## Menu principal del juego.
## Layout basado en Containers (Header + Body + Footer) con dimensiones fijas
## que NO se solapan entre si. La columna de codigo ambiente se genera proceduralmente.

const WORLD_SCENE_PATH := "res://scenes/iso/iso_demo.tscn"

@onready var quick_start_button: Button = $Body/MenuPanel/PanelPadding/VBox/QuickStartButton
@onready var continue_button: Button = $Body/MenuPanel/PanelPadding/VBox/ContinueButton
@onready var new_game_button: Button = $Body/MenuPanel/PanelPadding/VBox/NewGameButton
@onready var options_button: Button = $Body/MenuPanel/PanelPadding/VBox/SecondaryRow/OptionsButton
@onready var exit_button: Button = $Body/MenuPanel/PanelPadding/VBox/SecondaryRow/ExitButton
@onready var title_label: Label = $HeaderBar/TitlePadding/TitleColumn/TitleLabel
@onready var cursor_label: Label = $HeaderBar/TitlePadding/TitleColumn/SubtitleRow/CursorBlink
@onready var ambient_code: Control = $AmbientCode
@onready var title_underline: ColorRect = $HeaderBar/TitlePadding/TitleColumn/TitleUnderline
@onready var menu_panel: Panel = $Body/MenuPanel
@onready var header_bar: Panel = $HeaderBar
@onready var footer_bar: Panel = $Footer
@onready var version_label: Label = $Footer/FooterPadding/VersionLabel

var _code_scroll_tween: Tween

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	_apply_local_overrides()
	_apply_settings()
	_setup_splash()
	_setup_ambient_code()
	_setup_button_states()

	quick_start_button.pressed.connect(_on_quick_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_connect_cursor()

func _setup_button_states() -> void:
	continue_button.disabled = not SaveManager.has_save()
	if continue_button.disabled:
		continue_button.modulate = Color(0.55, 0.50, 0.45, 0.6)
		continue_button.tooltip_text = "No hay partida guardada"
	else:
		continue_button.tooltip_text = "Continuar tu última partida"

func _setup_splash() -> void:
	if not Splash.should_show():
		return
	var splash_scene: PackedScene = load("res://scenes/ui/splash.tscn")
	if splash_scene == null:
		return
	var splash: Node = splash_scene.instantiate()
	if splash == null:
		return
	add_child(splash)
	splash.z_index = 200

func _connect_cursor() -> void:
	var timer := get_node_or_null("HeaderBar/TitlePadding/TitleColumn/CursorTimer")
	if timer:
		timer.timeout.connect(_on_cursor_timer_timeout)

func _setup_ambient_code() -> void:
	# Genera lineas de codigo semi-transparentes que decoran el fondo
	# sin distraer (mueve lentamente hacia abajo, loop infinito).
	var vp := get_viewport().get_visible_rect().size
	var lines: Array[String] = [
		"int main() { return 0; }",
		"for (int i = 0; i < n; i++)",
		"while (ptr != nullptr)",
		"std::vector<int> v;",
		"if (arr[i] < arr[j])",
		"return result; // success",
		"void sort(int arr[], int n)",
		"delete[] buffer; // cleanup",
		"auto iter = map.find(key);",
		"class Renderer { void draw(); };",
		"template <typename T> T max(T a, T b)",
		"std::sort(v.begin(), v.end());",
		"template<class T> class Vector {};",
		"constexpr int N = 1024;",
		"for (auto& x : container) {",
		"nullptr != p && *p < value",
		"binary_search(vec.begin(), vec.end(), k)",
		"throw std::runtime_error(\"oops\");",
	]
	for line_text in lines:
		var label := Label.new()
		label.text = line_text
		label.add_theme_color_override("font_color", Color(0.42, 0.55, 0.42, randf_range(0.06, 0.14)))
		label.add_theme_font_size_override("font_size", 14)
		# Posicion aleatoria en X, Y inicial aleatoria (animara hacia abajo).
		var x: float = randf_range(40, max(vp.x - 300, 100))
		var y: float = randf_range(0, vp.y - 40)
		label.position = Vector2(x, y)
		label.z_index = -1
		ambient_code.add_child(label)

	# Animacion: cada label cae lentamente, reposicionandose al salir.
	_code_scroll_tween = create_tween().set_loops()
	for label_child in ambient_code.get_children():
		if label_child is Label:
			var captured_label: Label = label_child
			var target_y: float = vp.y + 40.0
			var start_y: float = captured_label.position.y
			var duration: float = 8.0 + randf() * 6.0
			_code_scroll_tween.parallel().tween_property(captured_label, "position:y", target_y, duration)
			_code_scroll_tween.tween_callback(func() -> void: _respawn_label(captured_label, start_y, vp))

func _respawn_label(label: Label, start_y: float, vp: Vector2) -> void:
	if not is_instance_valid(label):
		return
	label.position = Vector2(randf_range(40, max(vp.x - 300, 100)), start_y - vp.y)

func _apply_local_overrides() -> void:
	if menu_panel:
		menu_panel.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())
	if header_bar:
		header_bar.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
	if footer_bar:
		footer_bar.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
	if quick_start_button:
		quick_start_button.add_theme_color_override("font_color", D2Palette.GOLD_TEXT_BRIGHT)
		quick_start_button.add_theme_color_override("font_hover_color", D2Palette.GOLD_TEXT)
		quick_start_button.tooltip_text = "Iniciar partida o continuar la última"

func _apply_settings() -> void:
	var settings := SaveManager.load_settings()
	if settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## --- Handlers ---

func _on_quick_start_pressed() -> void:
	if SaveManager.has_save():
		_continue_quietly()
	else:
		_new_game_quietly()

func _continue_quietly() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		return
	GameManager.apply_save_data(data)
	_start_transition(true)

func _new_game_quietly() -> void:
	SaveManager.delete_save()
	GameManager.reset_to_new_game()
	_start_transition(false)

func _on_continue_pressed() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		return
	GameManager.apply_save_data(data)
	_start_transition(true)

func _on_new_game_pressed() -> void:
	SaveManager.delete_save()
	GameManager.reset_to_new_game()
	_start_transition(false)

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/options_menu.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

## use_transition=true: pasa por typewriter (sensacion "cargando partida").
## use_transition=false: fade-out directo a overworld (juego nuevo = arranque rapido).
func _start_transition(use_transition: bool) -> void:
	if use_transition:
		get_tree().change_scene_to_file("res://scenes/ui/code_transition.tscn")
		return
	# Fade-out del menu y carga directa de overworld.
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_cursor_timer_timeout() -> void:
	if cursor_label != null:
		cursor_label.visible = not cursor_label.visible