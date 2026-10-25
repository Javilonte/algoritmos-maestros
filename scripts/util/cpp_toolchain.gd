class_name CppToolchain
extends RefCounted

## El compilador de C++ de la maquina y las corridas de proceso.
##
## ponytail: hasta ahora cada consumidor tenia su propia lista de
## compiladores y su propio bucle de espera. El sandbox (que compila y
## corre el codigo del jugador) y el gate de forma (que lo parsea) usan
## el mismo clang, asi que la lista y la espera viven aca.
##
## ponytail: `-Xclang` (el flag que pide el dump del AST) es de CLANG.
## Con `g++` el gate se desactiva: la correccion la juzgan los test
## cases, no la forma del codigo.

# El preambulo que precede al codigo del jugador. Lo usan EL SANDBOX (que
# compila) y EL GATE (que parsea): el gate tiene que validar exactamente
# lo que se compila, o el jugador recibe un error de forma por un include
# que el harness ya le habia puesto.
const PREAMBLE: String = (
	"#include <fstream>\n#include <iostream>\n#include <string>\n#include <vector>\n"
	+ "using namespace std;\n\n"
)

const COMPILERS: Array[String] = ["clang++", "g++", "c++"]
const CLANG_COMPILERS: Array[String] = ["clang++"]
const WORK_DIR := "user://sandbox"
const DEFAULT_TIMEOUT_MS: int = 10000

static var _compiler: String = ""
static var _clang: String = ""


## El compilador de C++ disponible, cualquiera de los tres.
static func find_compiler() -> String:
	if not _compiler.is_empty():
		return _compiler
	for candidate in COMPILERS:
		if _runs(candidate):
			_compiler = candidate
			return _compiler
	return ""


## clang++ especifico: el dump del AST es una flag de clang.
static func find_clang() -> String:
	if not _clang.is_empty():
		return _clang
	for candidate in CLANG_COMPILERS:
		if _runs(candidate):
			_clang = candidate
			return _clang
	return ""


static func _runs(candidate: String) -> bool:
	var out: Array = []
	return OS.execute(candidate, ["--version"], out, true) == 0


## El directorio de trabajo (temporales) del sandbox.
static func work_dir() -> String:
	var dir: String = ProjectSettings.globalize_path(WORK_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


## Escribe un temporal y devuelve su ruta.
static func write_temp(stem: String, content: String, extension: String) -> String:
	var path: String = "%s/%s%s" % [work_dir(), stem, extension]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(content)
	f.close()
	return path


static func read_text(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


static func remove_file(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Corre un comando y espera a que termine.
##
## Devuelve {timed_out: bool, exit_code: int}. El comando se corre con
## /bin/sh para poder redirigir stdout y stderr a archivos: OS.create_process
## no captura stdout, y el dump del AST puede pesar cientos de KB.
##
## ponytail: el limite se mide con el reloj, no contando frames. En
## headless el bucle corre a cientos de fps y un timeout contado por
## frames duraba milisegundos de verdad.
static func run_shell(command: String, timeout_ms: int = DEFAULT_TIMEOUT_MS) -> Dictionary:
	var pid: int = OS.create_process("/bin/sh", ["-c", command], false)
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while pid > 0 and OS.is_process_running(pid):
		await _next_frame()
		if Time.get_ticks_msec() > deadline:
			OS.kill(pid)
			return {"timed_out": true, "exit_code": -1}
	return {"timed_out": false, "exit_code": OS.get_process_exit_code(pid)}


## Espera un frame del bucle principal. La pelea pausa el arbol, asi que
## la espera tiene que ser con un timer de process_always: el process_frame
## de la SceneTree no es la via fiable con el juego pausado.
static func _next_frame() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	await loop.create_timer(0.02, true).timeout
