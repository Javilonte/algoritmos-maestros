extends RefCounted
class_name LocalCppEvaluator

## Evaluador local simplificado. Solo reconoce operaciones aritmeticas
## y estructurales basicas; ignora el resto del codigo.
## Usado como fallback cuando Judge0 no esta disponible.

var PATTERN_ARITH: RegEx
var PATTERN_FUNC_DEF: RegEx

func _init() -> void:
	PATTERN_ARITH = RegEx.new()
	PATTERN_ARITH.compile("([\\+\\-\\*/%])")
	PATTERN_FUNC_DEF = RegEx.new()
	PATTERN_FUNC_DEF.compile("\\b(int|float|void|double|char)\\s+(\\w+)\\s*\\(")

func evaluate(code: String, _time_left: float) -> Dictionary:
	var has_main := code.contains("int main")
	var arith_count: int = _count_matches(PATTERN_ARITH, code)
	var func_count: int = _count_matches(PATTERN_FUNC_DEF, code)
	var has_semi := code.contains(";")
	var has_include := code.contains("#include")
	var score: int = 0
	var errors: Array[String] = []
	if not has_main and func_count == 0:
		errors.append("missing 'int main()'")
	if not has_semi and arith_count > 0:
		errors.append("missing semicolon")
		score = 0
	elif arith_count > 0:
		score = 10 + arith_count * 5
	elif func_count > 0:
		score = 15
	else:
		score = 5
	if has_include:
		score += 10
	var compiled: bool = errors.is_empty()
	var stdout: String = ""
	if compiled:
		stdout = "offline-eval: %d ops, %d funcs" % [arith_count, func_count]
	return {
		"compiled": compiled,
		"stdout": stdout,
		"stderr": "\n".join(errors),
		"compile_message": "",
		"time": 0.001,
		"memory": 1024,
		"status_id": 3 if compiled else 11,
		"raw_score": score,
	}

## Cuenta el numero de matches de un RegEx iterando con offsets.
## Reemplaza a RegEx.find_all() (no existe en Godot 4).
func _count_matches(pattern: RegEx, text: String) -> int:
	var count: int = 0
	var from: int = 0
	while from <= text.length():
		var m: RegExMatch = pattern.search(text, from)
		if m == null:
			break
		count += 1
		var end_pos: int = m.get_end()
		if end_pos <= from:
			# Evitar bucle infinito si el match tiene longitud 0.
			from += 1
		else:
			from = end_pos
	return count
