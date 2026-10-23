extends Node

## CodeValidator con heurísticas puramente GDScript.
## Da feedback inmediato (<10ms) sin depender de HTTP.
##
## NO reemplaza al sandbox HTTP: es una capa de pre-validacion
## que el BattleTerminal usa ANTES de enviar al sandbox para
## mostrar errores basicos en consola y evitar casts wasted.
##
## Si en el futuro se integra tree-sitter u otro parser real,
## se puede usar desde aqui como fallback mejorado.

## Evalua el codigo y retorna un dict con:
##   success: bool  - pasa las heuristicas minimas
##   message: String - resumen del resultado
##   issues: Array[Dictionary] - lista de issues encontrados
func evaluate(challenge_id: String, code: String) -> Dictionary:
	var issues: Array = []
	var trimmed: String = code.strip_edges()

	# Regla 1: codigo vacio.
	if trimmed.is_empty():
		issues.append({"severity": "error", "line": 0, "message": "empty code"})
		return _result(false, "empty code", issues)

	# Regla 2: presencia de main() (excepto para challenges especificos).
	if not challenge_id.is_empty() and not _challenge_allows_no_main(challenge_id):
		if not _has_main(code):
			issues.append({"severity": "warning", "line": 0, "message": "no 'int main()' found"})

	# Regla 3: balance de llaves y parentesis.
	var braces: int = _count_unbalanced(code, "{", "}")
	var parens: int = _count_unbalanced(code, "(", ")")
	if braces != 0:
		issues.append({"severity": "error", "line": 0, "message": "unbalanced braces (%d)" % braces})
	if parens != 0:
		issues.append({"severity": "error", "line": 0, "message": "unbalanced parentheses (%d)" % parens})

	# Regla 4: presencia de ; (al menos uno, heuristica basica).
	var semi_count: int = code.count(";")
	if semi_count == 0 and _has_cpp_statement(code):
		issues.append({"severity": "warning", "line": 0, "message": "no semicolons found"})

	# Regla 5: punteros sin liberar (new sin delete).
	if code.contains("new ") and not code.contains("delete"):
		issues.append({"severity": "warning", "line": 0, "message": "new without delete (memory leak)"})

	# Regla 6: malloc sin free.
	if code.contains("malloc") and not code.contains("free"):
		issues.append({"severity": "warning", "line": 0, "message": "malloc without free (memory leak)"})

	# Regla 7: longitud razonable (anti-spam).
	if code.length() > 4096:
		issues.append({"severity": "warning", "line": 0, "message": "code is very long"})

	var has_errors: bool = false
	for i in issues:
		if i.severity == "error":
			has_errors = true
			break

	if has_errors:
		var first_err: Dictionary = issues[0]
		return _result(false, first_err.message, issues)

	if issues.is_empty():
		return _result(true, "ok", issues)

	var first_warn: Dictionary = issues[0]
	return _result(true, first_warn.message + " (warnings)", issues)

func _result(success: bool, message: String, issues: Array) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"issues": issues,
	}

func _has_main(code: String) -> bool:
	# Acepta "int main", "int main()", "int main(int argc"...
	var re := RegEx.new()
	re.compile("int\\s+main\\s*\\(")
	return re.search(code) != null

func _count_unbalanced(code: String, open_ch: String, close_ch: String) -> int:
	# Elimina strings y comentarios para contar solo llaves/parens de codigo.
	var cleaned := _strip_strings_and_comments(code)
	return cleaned.count(open_ch) - cleaned.count(close_ch)

func _strip_strings_and_comments(code: String) -> String:
	var out := ""
	var i := 0
	var in_str := false
	var in_line_comment := false
	var in_block_comment := false
	while i < code.length():
		var ch := code[i]
		if in_line_comment:
			if ch == "\n":
				in_line_comment = false
				out += ch
			i += 1
			continue
		if in_block_comment:
			if ch == "*" and i + 1 < code.length() and code[i + 1] == "/":
				in_block_comment = false
				i += 2
				continue
			i += 1
			continue
		if in_str:
			if ch == "\\" and i + 1 < code.length():
				i += 2
				continue
			if ch == "\"":
				in_str = false
			i += 1
			continue
		if ch == "/" and i + 1 < code.length():
			if code[i + 1] == "/":
				in_line_comment = true
				i += 2
				continue
			if code[i + 1] == "*":
				in_block_comment = true
				i += 2
				continue
		if ch == "\"":
			in_str = true
			i += 1
			continue
		out += ch
		i += 1
	return out

func _has_cpp_statement(code: String) -> bool:
	# Si tiene keywords que sugieren statements reales (cout, return, int x = ...)
	return code.contains("cout") or code.contains("return ") or code.contains("int ") or code.contains("float ")

func _challenge_allows_no_main(challenge_id: String) -> bool:
	# Challenges que son fragmentos, no programas completos.
	var fragment_ids := ["code_snippet", "function_only"]
	return challenge_id in fragment_ids