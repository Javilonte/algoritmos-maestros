extends Control

## Menu principal del juego.
## Layout 3-columna (cyberpunk neon): HeroCard (izquierda) | Action grid (centro)
## | StatsPanel (derecha). Header con título + subtítulo + cursor parpadeante.
## Footer con accent line cyan.
##
## ponytail: ambient code in the background is themed to C++ skill tree
## keywords (templates, lower_bound, lambdas) instead of generic snippets
## so the menu subtly advertises the educational angle.

const WORLD_SCENE_PATH := "res://scenes/iso/iso_demo.tscn"

@onready var quick_start_button: MenuActionButton = $Body/CenterColumn/ActionGrid/QuickStartButton
@onready var continue_button: MenuActionButton = $Body/CenterColumn/ActionGrid/ContinueRow/ContinueButton
@onready var new_game_button: MenuActionButton = $Body/CenterColumn/ActionGrid/ContinueRow/NewGameButton
@onready var options_button: MenuActionButton = $Body/CenterColumn/ActionGrid/SecondaryRow/OptionsButton
@onready var exit_button: MenuActionButton = $Body/CenterColumn/ActionGrid/SecondaryRow/ExitButton
@onready var hero_card: MenuHeroCard = $Body/LeftColumn/HeroCard
@onready var stats_panel: MenuStatsPanel = $Body/RightColumn/StatsPanel
@onready var title_label: Label = $HeaderBar/TitlePadding/TitleColumn/TitleLabel
@onready var cursor_label: Label = $HeaderBar/TitlePadding/TitleColumn/SubtitleRow/CursorBlink
@onready var ambient_code: Control = $AmbientCode
@onready var header_bar: Panel = $HeaderBar
@onready var footer_bar: Panel = $Footer
@onready var version_label: Label = $Footer/FooterPadding/FooterRow/VersionLabel
@onready var neon_strip: Panel = $HeaderBar/NeonStrip

var _code_scroll_tween: Tween

# ponytail: keywords for the ambient code. Mirrors the SkillTree's
# unlocked skills, so the menu's background advertises what's coming.
const AMBIENT_LINES: Array[String] = [
	"std::sort(v.begin(), v.end());",
	"auto it = std::lower_bound(v.begin(), v.end(), k);",
	"template <typename T> T max(T a, T b) { return a > b ? a : b; }",
	"std::unordered_map<std::string, int> freq;",
	"auto lambda = [](int x) { return x * 2; };",
	"constexpr int N = 1 << 10;",
	"std::vector<std::unique_ptr<Node>> graph;",
	"std::optional<int> maybe = find(needle);",
	"for (auto& [k, v] : map) { /* iterate */ }",
	"std::move(src, dst);",
	"std::span<const int> window(arr, n);",
	"std::variant<int, std::string> result;",
	"std::ranges::find_if(vec, pred);",
	"co_await task.resume();",
	"std::format(\"{} {}\", a, b);",
	"std::bit_ceil(8u); // next power of two",
	"std::span<char> buf = stack.data();",
	"std::scoped_lock lk(mu1, mu2);",
]

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	_apply_local_overrides()
	_apply_settings()
	_setup_splash()
	_setup_ambient_code()
	_setup_button_states()
	# ponytail: connect the new components to SkillTree so they stay
	# live as the player progresses (only relevant if the menu is ever
	# shown mid-session; today it's only on app boot, but the wiring
	# costs nothing and avoids a regression later).
	if hero_card and hero_card.has_method("connect_to_skill_tree"):
		hero_card.connect_to_skill_tree()
	if stats_panel and stats_panel.has_method("connect_to_skill_tree"):
		stats_panel.connect_to_skill_tree()

	quick_start_button.pressed.connect(_on_quick_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_connect_cursor()


func _setup_button_states() -> void:
	# ponytail: Continue is now stateful. Disabled if no save; subtitle
	# line shows the reason.
	var has_save: bool = SaveManager.has_save()
	continue_button.disabled = not has_save
	if has_save:
		continue_button.set_subtitle_label("Tu última partida")
		continue_button.tooltip_text = "Continuar tu última partida"
	else:
		continue_button.set_subtitle_label("Sin partida guardada")
		continue_button.tooltip_text = "No hay partida guardada"
	# QuickStart inherits the same logic: if no save, treat as "Nuevo Juego".
	quick_start_button.set_subtitle_label(
		"Continuar la última" if has_save else "Empezar desde cero"
	)


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
	# ponytail: ambient code themed to C++ keywords. Slow scroll, low
	# opacity, infinite loop. Doesn't fight with the menu for input.
	var vp := get_viewport().get_visible_rect().size
	for line_text in AMBIENT_LINES:
		var label := Label.new()
		label.text = line_text
		label.add_theme_color_override("font_color", Color(0.0, 0.55, 0.50, randf_range(0.05, 0.14)))
		label.add_theme_font_size_override("font_size", 13)
		var x: float = randf_range(40, max(vp.x - 300, 100))
		var y: float = randf_range(0, vp.y - 40)
		label.position = Vector2(x, y)
		label.z_index = -1
		ambient_code.add_child(label)

	_code_scroll_tween = create_tween().set_loops()
	for label_child in ambient_code.get_children():
		if label_child is Label:
			var captured_label: Label = label_child
			var target_y: float = vp.y + 40.0
			var start_y: float = captured_label.position.y
			var duration: float = 10.0 + randf() * 8.0
			_code_scroll_tween.parallel().tween_property(captured_label, "position:y", target_y, duration)
			_code_scroll_tween.tween_callback(func() -> void: _respawn_label(captured_label, start_y, vp))


func _respawn_label(label: Label, start_y: float, vp: Vector2) -> void:
	if not is_instance_valid(label):
		return
	label.position = Vector2(randf_range(40, max(vp.x - 300, 100)), start_y - vp.y)


func _apply_local_overrides() -> void:
	if header_bar:
		header_bar.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
	if footer_bar:
		footer_bar.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())


func _apply_settings() -> void:
	var settings := SaveManager.load_settings()
	if settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# ponytail: apply persisted volume to Music + SFX buses on boot.
	var vol_pct: float = float(settings.get("volume", 80))
	var clamped: float = clampf(vol_pct / 100.0, 0.0, 1.0)
	var db: float = linear_to_db(clamped if clamped > 0.01 else 0.01)
	for bus_name in ["Music", "SFX"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, db)

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
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)


func _on_cursor_timer_timeout() -> void:
	if cursor_label != null:
		cursor_label.visible = not cursor_label.visible
