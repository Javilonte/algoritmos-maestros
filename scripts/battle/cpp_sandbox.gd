extends RefCounted
class_name CppSandbox

## Compila y ejecuta el codigo del jugador con clang++ en un sandbox local.
##
## ponytail: hasta ahora los runners de cada challenge llamaban a SU PROPIA
## solucion de referencia — el codigo del jugador nunca se ejecutaba y
## `main_exit_check` devolvia passed:true siempre. Esto compila lo que
## escribio el jugador y corre los test cases de verdad.
##
## ponytail: el codigo del jugador va SIEMPRE a un archivo, nunca a la
## linea de comandos. El comando es fijo y lo arma el juego, asi que no
## hay inyeccion posible. El shell solo se usa para redirigir la salida
## del compilador a un archivo.
##
## Ceiling: el codigo corre con los permisos del usuario, en su maquina.
## Es el codigo de el, escrito por el. El riesgo real no es el sandbox: es
## un loop infinito, y por eso el binario corre con timeout y en un
## proceso aparte. Un crash no toca el juego.

const COMPILERS: Array[String] = ["clang++", "g++", "c++"]
const CXX_STANDARD := "c++17"
const COMPILE_TIMEOUT_MS: int = 20000
const RUN_TIMEOUT_MS: int = 5000

var _compiler: String = ""
var _dir: String = ""
var _counter: int = 0


## Devuelve el compilador disponible, o "" si no hay ninguno.
func find_compiler() -> String:
	if not _compiler.is_empty():
		return _compiler
	for candidate in COMPILERS:
		var out: Array = []
		if OS.execute(candidate, ["--version"], out, true) == 0:
			_compiler = candidate
			return _compiler
	return ""


## Compila y corre el codigo del jugador contra los test cases del
## challenge. Es una corrutina: espera a los procesos.
##
## Devuelve:
##   compiled       bool    el compilador acepta el codigo
##   compile_output String  lo que dijo el compilador (errores de verdad)
##   timed_out      bool    el binario se colgo
##   runtime_output String  salida inesperada del binario
##   results        Array   un dict por caso: {passed, actual, error}
func run(code: String, challenge: ChallengeResource) -> Dictionary:
	var result: Dictionary = {
		"compiled": false,
		"compile_output": "",
		"timed_out": false,
		"runtime_output": "",
		"results": [],
	}
	var compiler: String = find_compiler()
	if compiler.is_empty():
		result["compile_output"] = "No hay compilador C++ en este sistema (clang++ / g++ / c++)."
		return result

	_ensure_dir()
	_counter += 1
	var stem: String = "chg_%d" % _counter
	var src_path: String = "%s/%s.cpp" % [_dir, stem]
	var bin_path: String = "%s/%s" % [_dir, stem]
	var log_path: String = "%s/%s.log" % [_dir, stem]
	var res_path: String = "%s/%s.out" % [_dir, stem]

	var source: String = _harness_source(code, challenge)
	var f := FileAccess.open(src_path, FileAccess.WRITE)
	if f == null:
		result["compile_output"] = "No se pudo escribir el archivo temporal."
		return result
	f.store_string(source)
	f.close()

	# --- compilar ------------------------------------------------------------
	var cmd := "%s -std=%s -O0 -o '%s' '%s' > '%s' 2>&1" % [
		compiler, CXX_STANDARD, bin_path, src_path, log_path]
	var pid: int = OS.create_process("/bin/sh", ["-c", cmd], false)
	# ponytail: el limite se mide con el reloj, no contando frames. En
	# headless el bucle corre a cientos de fps y un timeout contado por
	# frames duraba milisegundos de verdad.
	var deadline: int = Time.get_ticks_msec() + COMPILE_TIMEOUT_MS
	while pid > 0 and OS.is_process_running(pid):
		await _next_frame()
		if Time.get_ticks_msec() > deadline:
			OS.kill(pid)
			result["compile_output"] = "La compilacion tardo demasiado y se cancelo."
			_cleanup(stem)
			return result
	var log_text: String = _read_text(log_path)
	# ponytail: el error del compilador trae la ruta absoluta del temporal
	# ("/Users/tu/Library/Application Support/Godot/..."). Se corta: al
	# jugador le importa el archivo y la linea, no donde esta el sandbox.
	if not _dir.is_empty():
		log_text = log_text.replace(_dir + "/", "")
	if not FileAccess.file_exists(bin_path):
		result["compile_output"] = log_text if not log_text.is_empty() else "La compilacion fallo sin mensaje."
		_cleanup(stem)
		return result
	result["compiled"] = true
	result["compile_output"] = log_text

	# --- correr --------------------------------------------------------------
	# El binario escribe los resultados a un archivo: no hace falta
	# capturar stdout y el timeout es real.
	var run_pid: int = OS.create_process(bin_path, [res_path], false)
	deadline = Time.get_ticks_msec() + RUN_TIMEOUT_MS
	while run_pid > 0 and OS.is_process_running(run_pid):
		await _next_frame()
		if Time.get_ticks_msec() > deadline:
			OS.kill(run_pid)
			result["timed_out"] = true
			result["runtime_output"] = "Tu codigo se colgo (limite de %d s)." % (RUN_TIMEOUT_MS / 1000)
			_cleanup(stem)
			return result
	result["runtime_output"] = _read_text(res_path)
	result["results"] = _parse_results(_read_text(res_path), challenge)
	_cleanup(stem)
	return result


## El harness: los includes, el codigo del jugador y una llamada por caso
## de prueba que escribe el resultado a un archivo.
func _harness_source(code: String, challenge: ChallengeResource) -> String:
	var head := "#include <fstream>\n#include <iostream>\n#include <string>\n#include <vector>\nusing namespace std;\n\n"
	head += code
	head += "\n\n"
	# ponytail: el challenge "main_exit_check" ES escribir un main: el
	# harness no puede definir otro main o el codigo no compila.
	if challenge.function_name_hint == "main":
		return head
	head += "int main(int argc, char** argv) {\n    std::ofstream out(argv[1]);\n"
	var params: Array = _parse_params(challenge.function_signature)
	for i in challenge.test_cases.size():
		head += _call_for(challenge.test_cases[i], params, challenge)
	head += "    return 0;\n}\n"
	return head


## Una llamada por caso: declara los argumentos con el tipo de la
## firma y escribe el resultado.
func _call_for(test: TestCase, params: Array, challenge: ChallengeResource) -> String:
	var decls: String = ""
	var args: String = ""
	for i in params.size():
		var type: String = String(params[i][0])
		var value: Variant = test.inputs[i] if i < test.inputs.size() else 0
		var var_name: String = "_a%d" % i
		decls += "        %s %s = %s;\n" % [_cpp_type(type), var_name, _cpp_literal(value, type)]
		if not args.is_empty():
			args += ", "
		args += var_name
	var returns_vector: bool = challenge.function_signature.begins_with("vector<")
	if returns_vector:
		return (
			"    {\n" + decls
			+ "        auto _r = %s(%s);\n" % [challenge.function_name_hint, args]
			+ "        out << \"RESULT \" << _r.size();\n"
			+ "        for (auto _v : _r) { out << \" \" << _v; }\n"
			+ "        out << \"\\n\";\n"
			+ "    }\n")
	return (
		"    {\n" + decls
		+ "        int _r = %s(%s);\n" % [challenge.function_name_hint, args]
		+ "        out << \"RESULT 1 \" << _r << \"\\n\";\n"
		+ "    }\n")


## "int binarySearch(vector<int> arr, int target)" → [["vector<int>","arr"],["int","target"]]
func _parse_params(signature: String) -> Array:
	var open: int = signature.find("(")
	var close: int = signature.rfind(")")
	if open == -1 or close == -1 or close < open:
		return []
	var inner: String = signature.substr(open + 1, close - open - 1)
	var out: Array = []
	for part in inner.split(",", false):
		var chunk: String = part.strip_edges()
		var space: int = chunk.rfind(" ")
		if space == -1:
			out.append([chunk, ""])
		else:
			out.append([chunk.substr(0, space), chunk.substr(space + 1)])
	return out


func _cpp_type(type: String) -> String:
	if type.begins_with("vector<"):
		return "std::vector<int>"
	return type


func _cpp_literal(value: Variant, type: String) -> String:
	if type.begins_with("vector<"):
		var parts: Array[String] = []
		if value is Array:
			for item in value:
				parts.append(str(item))
		return "{%s}" % ", ".join(parts)
	return str(int(value))


## Lee las lineas RESULT y las compara con lo esperado.
func _parse_results(raw: String, challenge: ChallengeResource) -> Array:
	var out: Array = []
	var lines: PackedStringArray = raw.split("\n")
	var index: int = 0
	for line in lines:
		var text: String = line.strip_edges()
		if not text.begins_with("RESULT"):
			continue
		if index >= challenge.test_cases.size():
			break
		out.append(_compare(text, challenge.test_cases[index]))
		index += 1
	return out


func _compare(line: String, test: TestCase) -> Dictionary:
	var tokens: PackedStringArray = line.substr(6).strip_edges().split(" ", false)
	var count: int = int(tokens[0]) if tokens.size() > 0 else 0
	var values: Array = []
	for i in range(1, min(count + 1, tokens.size())):
		values.append(int(tokens[i]))
	var expected: Variant = test.expected
	var passed: bool = false
	if expected is Array:
		var expected_list: Array = expected
		passed = values.size() == expected_list.size()
		if passed:
			for i in expected_list.size():
				if int(values[i]) != int(expected_list[i]):
					passed = false
					break
	else:
		passed = values.size() == 1 and int(values[0]) == int(expected)
	var error: String = ""
	if not passed:
		# ponytail: el "got" con la misma forma que el "expected". Un
		# "expected 3, got [0]" obliga a el jugador a descifrar que el 0
		# es un vector de un elemento.
		var actual_text: String = str(values[0]) if values.size() == 1 and not (expected is Array) else str(values)
		error = "expected %s, got %s" % [str(expected), actual_text]
	return {"passed": passed, "actual": values, "error": error, "name": test.name}


## Espera un frame del bucle principal. La pelea pausa el arbol, asi que
## la espera tiene que ser con un timer de process_always: el process_frame de
## la SceneTree no es la via fiable con el juego pausado.
func _next_frame() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	await loop.create_timer(0.02, true).timeout


func _ensure_dir() -> void:
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://sandbox")
		DirAccess.make_dir_recursive_absolute(_dir)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


func _cleanup(stem: String) -> void:
	for suffix in [".cpp", ".log", ".out"]:
		var path: String = "%s/%s%s" % [_dir, stem, suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var bin: String = "%s/%s" % [_dir, stem]
	if FileAccess.file_exists(bin):
		DirAccess.remove_absolute(bin)
