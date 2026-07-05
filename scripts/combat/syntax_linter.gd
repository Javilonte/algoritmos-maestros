extends Node
class_name SyntaxLinter

## Linter visual en tiempo real para código C++.
## Detecta errores comunes (falta de ;, llaves desbalanceadas, cout sin ;).
## Se conecta a la señal text_changed de CodeEdit y emite issues.

signal issues_updated(issues: Array)

const KEYWORDS := ["int", "float", "double", "char", "bool", "void",
	"if", "else", "for", "while", "do", "return",
	"cout", "cin", "endl", "new", "delete",
	"class", "struct", "public", "private", "protected",
	"template", "typename", "namespace", "using", "std",
	"const", "static", "auto", "nullptr", "true", "false"]

var open_braces: int = 0
var open_parens: int = 0
var last_issues: Array = []

func lint(code: String) -> Array:
	var issues: Array = []
	open_braces = 0
	open_parens = 0
	var lines := code.split("\n")
	for line_idx in range(lines.size()):
		var line: String = lines[line_idx]
		var stripped := _strip_strings_and_comments(line)
		open_braces += stripped.count("{")
		open_braces -= stripped.count("}")
		open_parens += stripped.count("(")
		open_parens -= stripped.count(")")
		# Detectar cout sin ; al final de línea (heurística simple).
		if stripped.contains("cout") and not stripped.ends_with(";") and not stripped.ends_with("{") and not stripped.ends_with("}"):
			if not _next_line_starts_block(lines, line_idx):
				issues.append({
					"line": line_idx,
					"col": stripped.find("cout"),
					"severity": "error",
					"message": "cout statement missing semicolon",
				})
		# Línea no vacía sin ; y que no abre bloque
		var trimmed := stripped.strip_edges()
		if not trimmed.is_empty() \
			and not trimmed.ends_with(";") \
			and not trimmed.ends_with("{") \
			and not trimmed.ends_with("}") \
			and not trimmed.ends_with(":") \
			and not trimmed.begins_with("//") \
			and not trimmed.begins_with("#") \
			and not _is_keyword_only(trimmed) \
			and not trimmed.ends_with(","):
			# ignorar declaraciones multi-línea obvias
			if not _looks_like_open_decl(trimmed):
				issues.append({
					"line": line_idx,
					"col": trimmed.length() - 1,
					"severity": "warning",
					"message": "statement may be missing semicolon",
				})
	if open_braces != 0:
		issues.append({
			"line": lines.size() - 1,
			"col": 0,
			"severity": "error",
			"message": "unbalanced braces: %d open" % open_braces,
		})
	if open_parens != 0:
		issues.append({
			"line": lines.size() - 1,
			"col": 0,
			"severity": "error",
			"message": "unbalanced parentheses: %d open" % open_parens,
		})
	last_issues = issues
	issues_updated.emit(issues)
	return issues

func get_error_count() -> int:
	var count := 0
	for i in last_issues:
		if i.severity == "error":
			count += 1
	return count

func get_warning_count() -> int:
	var count := 0
	for i in last_issues:
		if i.severity == "warning":
			count += 1
	return count

func _strip_strings_and_comments(line: String) -> String:
	## Elimina contenido de strings y comentarios para no contar sus llaves.
	var result := ""
	var i := 0
	var in_str := false
	var in_lc := false
	while i < line.length():
		var ch := line[i]
		if in_lc:
			break
		if in_str:
			if ch == "\"" and (i == 0 or line[i-1] != "\\"):
				in_str = false
			i += 1
			continue
		if ch == "\"":
			in_str = true
			i += 1
			continue
		if ch == "/" and i + 1 < line.length() and line[i+1] == "/":
			in_lc = true
			break
		result += ch
		i += 1
	return result

func _next_line_starts_block(lines: PackedStringArray, idx: int) -> bool:
	for j in range(idx + 1, lines.size()):
		if lines[j].strip_edges() != "":
			return lines[j].strip_edges().begins_with("{")
	return false

func _is_keyword_only(line: String) -> bool:
	for kw in KEYWORDS:
		if line == kw or line == kw + ":":
			return true
	return false

func _looks_like_open_decl(line: String) -> bool:
	## "int x =" o "for (int" no termina en ; pero está OK.
	if line.contains("=") and not line.ends_with(";"):
		return true
	if line.begins_with("for ") or line.begins_with("while ") or line.begins_with("if "):
		return true
	if line.begins_with("return"):
		return true
	return false

## Construye un CodeHighlighter con los keywords C++.
static func build_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.6, 0.6, 0.6)
	h.symbol_color = Color(0.9, 0.7, 0.2)
	h.function_color = Color(0.4, 0.8, 1.0)
	var keyword_colors: Dictionary = {}
	for kw in KEYWORDS:
		keyword_colors[kw] = Color(0.85, 0.4, 0.95)
	h.keyword_colors = keyword_colors
	# Strings y char literals: Godot 4 usa color_regions como delimitador
	# unico (el primer caracter se trata como apertura, hasta el siguiente).
	h.color_regions = {
		"\"": Color(0.7, 0.95, 0.7),  # string C++
		"'": Color(0.7, 0.95, 0.7),   # char literal
	}
	return h
