extends CanvasLayer
class_name BattleTerminal

## Terminal de combate con:
## - Editor de código (CodeEdit) con highlighting C++.
## - Linter en tiempo real.
## - Timer de 30s con pausa atómica al enviar.
## - Macros (Alt+1..5) para insertar snippets.
## - Layout responsive: se clampa al viewport en _ready.

signal submitted(success: bool)
signal code_submitted(code: String)
signal time_out
signal back_pressed
signal locked_changed(is_locked: bool)
signal char_typed(ch: String)
signal macro_used(macro_name: String)

@export var round_duration: float = 30.0

@onready var outer_frame: Panel = $OuterFrame
@onready var inner_panel: Panel = $OuterFrame/InnerPanel
@onready var header_bar: Panel = $OuterFrame/HeaderBar
@onready var code_editor: CodeEdit = $OuterFrame/InnerPanel/CodeEdit
@onready var console_output: RichTextLabel = $OuterFrame/InnerPanel/ConsoleOutput
@onready var submit_button: Button = $OuterFrame/InnerPanel/ButtonRow/SubmitButton
@onready var back_button: Button = $OuterFrame/InnerPanel/ButtonRow/BackButton
@onready var timer_label: Label = $OuterFrame/HeaderBar/TimerLabel
@onready var title_label: Label = $OuterFrame/HeaderBar/TitleBar
@onready var linter_status: RichTextLabel = $OuterFrame/InnerPanel/LinterStatus
@onready var macro_bar: HBoxContainer = $OuterFrame/InnerPanel/MacroBar
@onready var spinner: Label = $OuterFrame/InnerPanel/SpinnerLabel

var _challenge_id: String = "main_exit_check"
var _is_busy: bool = false
var _is_locked: bool = false
var _timer: Timer
var linter: SyntaxLinter
var macros: Array[String] = []
var macro_snippets: Dictionary = {}

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_responsive_layout()
	_apply_local_overrides()
	linter = SyntaxLinter.new()
	add_child(linter)
	code_editor.syntax_highlighter = SyntaxLinter.build_highlighter()
	code_editor.text_changed.connect(_on_text_changed)
	linter.issues_updated.connect(_on_lint_issues)
	_setup_timer()
	_setup_macros()
	set_process_unhandled_key_input(true)

func _apply_responsive_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var w: float = clampf(vp.x - UIMetrics.VIEWPORT_MARGIN * 2, 800, UIMetrics.TERMINAL_WIDTH)
	var h: float = clampf(vp.y - UIMetrics.VIEWPORT_MARGIN * 2, 420, UIMetrics.TERMINAL_HEIGHT)
	if outer_frame:
		outer_frame.size = Vector2(w, h)
		outer_frame.position = (vp - Vector2(w, h)) * 0.5

func _apply_local_overrides() -> void:
	if outer_frame:
		outer_frame.add_theme_stylebox_override("panel", D2StyleBox.panel_bronze())
	if inner_panel:
		inner_panel.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
	if header_bar:
		header_bar.add_theme_stylebox_override("panel", D2StyleBox.panel_inner())
	if timer_label:
		timer_label.add_theme_color_override("font_color", D2Palette.BONE_TEXT)
	if code_editor:
		code_editor.add_theme_font_size_override("font_size", UIMetrics.FONT_CODE)
	if submit_button:
		submit_button.add_theme_font_size_override("font_size", UIMetrics.FONT_BODY)
	if back_button:
		back_button.add_theme_font_size_override("font_size", UIMetrics.FONT_LABEL + 1)

func _setup_timer() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = round_duration
	_timer.autostart = false
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)

func _setup_macros() -> void:
	macro_snippets = {
		"dmg1": "int dmg = %X%;",
		"crit": "if (rand()%%100 < 25) dmg *= 2;",
		"loop": "for (int i=0; i<%N%; ++i) { %CURSOR% }",
		"free": "delete ptr; ptr = nullptr;",
		"sort": "std::sort(v.begin(), v.end());",
	}
	var raw_keys: Array = macro_snippets.keys()
	macros.clear()
	for k in raw_keys:
		macros.append(String(k))
	_refresh_macro_bar()

func _refresh_macro_bar() -> void:
	if macro_bar == null:
		return
	for child in macro_bar.get_children():
		child.queue_free()
	for i in range(macros.size()):
		var macro_name: String = macros[i]
		var btn := Button.new()
		btn.text = "Alt+%d %s" % [i + 1, macro_name]
		btn.custom_minimum_size = Vector2(120, 24)
		btn.pressed.connect(_on_macro_button.bind(macro_name))
		macro_bar.add_child(btn)

## --- API pública ---

func open_for(challenge_id: String) -> void:
	_challenge_id = challenge_id
	_is_busy = false
	_is_locked = false
	code_editor.text = ""
	var challenge := ChallengeRegistry.fetch(StringName(challenge_id))
	var prompt_text := "[color=#8c8068]// Write code to attack![/color]\n"
	var placeholder_hint := "// Write C++ here..."
	if challenge != null:
		title_label.text = "Write C++ to defeat %s!" % String(_enemy_display_name(challenge.display_name))
		if not challenge.hint_lines.is_empty():
			placeholder_hint = String(challenge.hint_lines[0])
		if not challenge.prompt.is_empty():
			prompt_text = "[color=#ebcb8b]// %s[/color]\n" % challenge.prompt.replace("\n", "\n// ")
			if not challenge.hint_lines.is_empty():
				prompt_text += "\n[color=#88c0d0]// Hints:[/color]\n"
				for hint in challenge.hint_lines:
					prompt_text += "[color=#88c0d0]//   %s[/color]\n" % hint
			prompt_text += "\n[color=#8c8068]// Write code to attack![/color]\n"
	code_editor.placeholder_text = placeholder_hint
	console_output.text = prompt_text
	visible = true
	code_editor.editable = true
	code_editor.grab_focus()
	locked_changed.emit(false)

func _enemy_display_name(fallback: String) -> String:
	var battle: Node = get_tree().get_root().find_child("Battle", true, false)
	if battle:
		var controller: Node = battle.get_node_or_null("CombatController")
		if controller and "current_enemy" in controller and controller.current_enemy is Dictionary:
			var name_val: String = String(controller.current_enemy.get("display_name", fallback))
			if not name_val.is_empty():
				return name_val
	return fallback

func close() -> void:
	_timer.stop()
	visible = false

func lock(is_locked: bool) -> void:
	_is_locked = is_locked
	code_editor.editable = not is_locked
	if spinner:
		spinner.visible = is_locked
		if is_locked:
			_spinner_tick = 0.0
	locked_changed.emit(is_locked)

func pause_timer() -> void:
	_timer.paused = true

func resume_timer() -> void:
	_timer.paused = false

func get_time_left() -> float:
	return _timer.time_left

func get_code() -> String:
	return code_editor.text

func reset_for_next_round() -> void:
	code_editor.text = ""
	console_output.text = ""
	code_editor.editable = true
	_is_locked = false
	_is_busy = false
	_timer.start(round_duration)
	_update_timer_label(round_duration)
	code_editor.grab_focus()
	locked_changed.emit(false)

## --- Internals ---

func _process(delta: float) -> void:
	if not visible or _is_locked:
		return
	var remaining := _timer.time_left
	_update_timer_label(remaining)
	if remaining < 5.0:
		timer_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		timer_label.modulate = Color(1, 1, 1)
	if _is_locked and spinner.visible:
		_spinner_tick += delta
		var frames := ["[|]", "[/]", "[-]", "[\\\\]"]
		var idx := int(_spinner_tick * 8) % frames.size()
		spinner.text = "Compiling… %s" % frames[idx]

var _spinner_tick: float = 0.0

func _update_timer_label(t: float) -> void:
	if timer_label:
		timer_label.text = "%.1fs" % t

func _on_text_changed() -> void:
	linter.lint(code_editor.text)

func _on_lint_issues(issues: Array) -> void:
	if linter_status == null:
		return
	var errors := 0
	var warnings := 0
	for i in issues:
		if i.severity == "error":
			errors += 1
		elif i.severity == "warning":
			warnings += 1
	if errors > 0:
		linter_status.text = "[color=#bf616a]%d error(s)[/color]" % errors
	elif warnings > 0:
		linter_status.text = "[color=#ebcb8b]%d warning(s)[/color]" % warnings
	else:
		linter_status.text = "[color=#a3be8c]OK[/color]"

func _on_timer_timeout() -> void:
	if _is_locked:
		return
	time_out.emit()
	_on_submit_pressed()

func _on_submit_pressed() -> void:
	if _is_busy or _is_locked:
		return
	if code_editor.text.strip_edges().is_empty():
		console_output.append_text("[color=#ebcb8b]>> empty code, nothing to compile[/color]\n")
		return
	_is_busy = true
	var code := code_editor.text
	var snapshot := _timer.time_left
	_timer.paused = true
	lock(true)
	console_output.append_text("[color=#88c0d0]>> submitting… (timer frozen at %.1fs)[/color]\n" % snapshot)
	var result := CodeValidator.evaluate(_challenge_id, code)
	if result.success:
		console_output.append_text("[color=#a3be8c]>> compile OK[/color]\n")
		submitted.emit(true)
	else:
		console_output.append_text("[color=#bf616a]>> compile failed: %s[/color]\n" % result.message)
		submitted.emit(false)
	code_submitted.emit(code)
	_is_busy = false

func _on_back_pressed() -> void:
	close()
	back_pressed.emit()

func _on_macro_button(macro_name: String) -> void:
	_insert_macro(macro_name)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _is_locked:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not event.alt_pressed:
		return
	var kc: int = event.keycode
	var idx := -1
	if kc >= KEY_1 and kc <= KEY_5:
		idx = kc - KEY_1
	if idx >= 0 and idx < macros.size():
		_insert_macro(macros[idx])
		get_viewport().set_input_as_handled()

func _insert_macro(macro_name: String) -> void:
	if not macro_snippets.has(macro_name):
		return
	var snippet: String = macro_snippets[macro_name]
	snippet = snippet.replace("%X%", "10")
	snippet = snippet.replace("%N%", "n")
	var cursor_token := "%CURSOR%"
	var cursor_offset := snippet.find(cursor_token)
	if cursor_offset >= 0:
		snippet = snippet.replace(cursor_token, "")
	code_editor.insert_text_at_caret(snippet)
	macro_used.emit(macro_name)
	char_typed.emit(macro_name)