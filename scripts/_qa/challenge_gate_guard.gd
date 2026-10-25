extends Node

## Guard: TODO challenge tiene que ser ganable.
##
## ponytail: el gate de forma del AST es la unica verificacion real de la
## pelea (el codigo del jugador todavia no se ejecuta). Si un challenge
## declara una feature con un nombre que el gate no conoce —"if" en vez de
## "conditional"— el gate la pide igual, la busca en el codigo, no la
## encuentra nunca y el challenge es IMPOSIBLE. Pasó con `simple_dp` y
## `binary_search`, y `simple_dp` es el primer enemigo del Nivel 01: la
## tutorial era invencible.
##
## Este guard arma, para cada challenge, un C++ que contiene las cuatro
## estructuras que el gate conoce (bucle, condicion, llamada, return) y lo
## pasa por el gate REAL. Si un challenge pide algo imposible, el guard
## falla y dice que feature es.

const WORLD := "res://scenes/battle/../.."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0
	var ids: PackedStringArray = ChallengeRegistry.list_all().map(func(c): return String(c.id))
	if ids.is_empty():
		print("FAIL: the challenge registry is empty")
		get_tree().quit(1)
		return

	for id in ids:
		var challenge: ChallengeResource = ChallengeRegistry.get_by_id(id)
		if challenge == null:
			failed += 1
			print("FAIL: '%s' is in the registry but does not load" % id)
			continue

		# el nombre de la funcion tiene que coincidir con la firma: si no,
		# el gate pide una funcion que el starter code no tiene.
		if not challenge.function_signature.contains(challenge.function_name_hint):
			failed += 1
			print("FAIL: '%s' asks for function '%s' but the signature is '%s'"
				% [id, challenge.function_name_hint, challenge.function_signature])
			continue

		var solution: String = _solution_with_every_structure(challenge)
		var ast: Dictionary = await AstValidator.validate(solution, challenge)
		if bool(ast.get("valid", false)):
			passed += 1
			print("PASS: '%s' is winnable (needs %s)"
				% [id, ", ".join(challenge.ast_required_features)])
		else:
			failed += 1
			var missing: Array = ast.get("required_features_missing", [])
			print("FAIL: '%s' is UNWINNABLE — the gate rejects a correct solution"
				% id)
			print("      required features: %s" % ", ".join(challenge.ast_required_features))
			print("      the gate could not find: %s" % ", ".join(missing))
			print("      errors: %s" % str(ast.get("errors", [])))

	print("\n========== CHALLENGE GATE GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


## Un C++ que contiene las cuatro estructuras que el gate conoce: bucle,
## condicion, llamada a funcion y return. Si el challenge pide un subconjunto
## de ellas, esta solucion lo satisface.
##
## ponytail: el template va en el PADRE de la funcion (asi es como lo
## parsea tree-sitter-cpp), asi que la solucion del probe se declara
## `template <typename T>` cuando el challenge lo pide.
##
## ponytail: el probe tiene que COMPILAR, no solo parsear. Con clang (que
## es el gate ahora) devolver un int de una funcion que devuelve
## vector<int> es un error de compilacion, no un detalle de forma: el
## probe declara una variable del tipo de retorno y la devuelve.
func _solution_with_every_structure(challenge: ChallengeResource) -> String:
	var head: String = ""
	if "template" in challenge.ast_required_features:
		head = "template <typename T>\n"
	var return_type: String = AstValidator._extract_return_token(String(challenge.function_signature))
	if return_type.is_empty():
		return_type = "int"
	return (
		"int __probe(int x) { return x; }\n"
		+ "using __R = %s;\n" % return_type
		+ head + challenge.function_signature + " {\n"
		+ "\t__R __r;\n"
		+ "\tint __t = 0;\n"
		+ "\tint __u = 0;\n"
		+ "\tfor (int __i = 0; __i < 3; __i++) {\n"
		+ "\t\tif (__i % 2 == 0) {\n"
		+ "\t\t\t__t += __probe(__i);\n"
		+ "\t\t} else {\n"
		+ "\t\t\t__t -= __probe(__i);\n"
		+ "\t\t}\n"
		+ "\t}\n"
		+ "\twhile (__u < 2) { __u++; }\n"
		+ "\treturn __r;\n"
		+ "}\n"
	)
