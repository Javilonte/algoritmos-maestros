class_name AstValidator
extends RefCounted

# Valida la FORMA del codigo del jugador: que exista la funcion pedida, que
# devuelva el tipo correcto y que use las estructuras que el challenge exige.
#
# ponytail: esto solia ser una GDExtension en C++ con tree-sitter
# (gdextension/src/validators.cpp). El juego ya exige clang++ para el
# sandbox de la pelea: dos cadenas de compilacion para leer el mismo
# codigo era un peso, y el binario de Windows que se shippeaba quedaba
# viejo en silencio (no conocia la feature `template`, asi que ese
# challenge era invencible en Windows).
#
# Ahora el gate lee el AST que produce el mismo clang. El mapeo es 1:1:
#   tree-sitter            clang
#   for_statement          ForStmt
#   while_statement        WhileStmt
#   do_statement           DoStmt
#   if_statement           IfStmt
#   call_expression        CallExpr
#   return_statement       ReturnStmt
#   template_declaration   FunctionTemplateDecl (el padre de la funcion)
#
# Es una CORRUTINA: corre clang en un proceso aparte, asi que hay que
# `await AstValidator.validate(...)`.

const AST_VALID_LOOKUP_ERRORS := {
	"missing_function": "Function '{expected}' was not declared in your code.",
	"return_mismatch": "Return type mismatch: expected a type containing '{expected}', got '{actual}'.",
	"missing_features": "Missing required feature(s): {features}.",
	"too_simple": "Function body too simple: need at least {min} statement(s), got {actual}.",
	"syntax_error": "Syntax error: code did not parse as valid C++.",
}

# Los kinds de clang que cuentan como statement. Mismo criterio que el
# contador de tree-sitter: una declaracion, una expresion, las estructuras
# de control y los bloques.
const STATEMENT_KINDS: Array[String] = [
	"DeclStmt", "ExprStmt", "IfStmt", "ForStmt", "WhileStmt", "DoStmt",
	"RangeForStmt", "ReturnStmt", "CompoundStmt",
]
const LOOP_KINDS: Array[String] = ["ForStmt", "WhileStmt", "DoStmt", "RangeForStmt"]
# ponytail: tree-sitter llamaba "call_expression" a TODO lo que se invoca.
# clang lo parte en cuatro kinds: una llamada a funcion, una a un metodo, una
# a un operador sobrecargado y la construccion de un objeto
# (`std::thread(...)` es un CXXConstructExpr, no un CallExpr).
const CALL_KINDS: Array[String] = [
	"CallExpr", "CXXMemberCallExpr", "CXXOperatorCallExpr", "CXXConstructExpr",
]

const TIMEOUT_MS: int = 10000

# Builds a structure_spec Dictionary from a ChallengeResource.
static func build_spec_from_challenge(challenge: ChallengeResource) -> Dictionary:
	var spec := {
		"function_name": String(challenge.function_name_hint),
		"expected_return": _extract_return_token(String(challenge.function_signature)),
		"min_statements": int(challenge.ast_min_statements) if int(challenge.ast_min_statements) > 0 else 1,
		"required_features": Array(challenge.ast_required_features),
	}
	return spec


## Valida el codigo del jugador. CORRUTINA: hay que awaitearla.
##
## Devuelve el mismo contrato que la extension de C++ devolvia:
## valid, function_found, function_name, return_type_match,
## actual_return_type, param_count, statement_count, has_loop,
## has_conditional, has_call, has_return, has_template,
## required_features_missing, errors, quality, feature_summary.
static func validate(code: String, challenge: ChallengeResource) -> Dictionary:
	var spec: Dictionary = build_spec_from_challenge(challenge)
	var result: Dictionary = _blank(spec)
	result["feature_summary"] = "no_clang"

	var clang: String = CppToolchain.find_clang()
	if clang.is_empty():
		# ponytail: sin clang no hay AST, pero la pelea sigue: la
		# correccion la juzgan los test cases, no la forma del codigo.
		result["errors"] = ["No hay clang++ en este sistema: la validacion de forma esta desactivada."]
		return result

	var stem: String = "ast_%d" % Time.get_ticks_usec()
	# ponytail: el gate parsea con clang, y clang necesita los includes que
	# usa el codigo. Se antepone el MISMO preambulo del sandbox: si el
	# codigo no compila, el error es real (el sandbox tampoco lo compila).
	var src_path: String = CppToolchain.write_temp(stem, CppToolchain.PREAMBLE + code, ".cpp")
	if src_path.is_empty():
		result["errors"] = ["No se pudo escribir el codigo temporal."]
		return result
	var dir: String = CppToolchain.work_dir()
	var json_path: String = "%s/%s.json" % [dir, stem]
	var log_path: String = "%s/%s.log" % [dir, stem]
	# ponytail: el filtro por funcion achica el dump (66 KB -> 34 KB) y, si
	# la funcion no existe, el dump sale vacio: que es justo el caso
	# "function not found".
	var command: String = (
		"%s -std=c++17 -Xclang -ast-dump=json -Xclang -ast-dump-filter=%s "
		+ "-fsyntax-only '%s' > '%s' 2> '%s'"
	) % [clang, _shell_quote(String(spec["function_name"])), src_path, json_path, log_path]
	var run: Dictionary = await CppToolchain.run_shell(command, TIMEOUT_MS)
	var log_text: String = CppToolchain.read_text(log_path)
	var raw: String = CppToolchain.read_text(json_path)
	CppToolchain.remove_file(src_path)
	CppToolchain.remove_file(json_path)
	CppToolchain.remove_file(log_path)

	if bool(run.get("timed_out", false)):
		result["errors"] = ["La validacion del codigo tardo demasiado."]
		return result
	if int(run.get("exit_code", 0)) != 0:
		result["errors"] = _clang_errors(log_text, dir)
		result["feature_summary"] = "syntax_error"
		return result

	var found: Dictionary = _extract_function(raw, String(spec["function_name"]))
	if found.is_empty():
		result["errors"] = ["No se pudo leer el AST del codigo."]
		result["feature_summary"] = "no_ast"
		return result
	if found.is_empty():
		result["errors"] = [AST_VALID_LOOKUP_ERRORS["missing_function"].format({"expected": spec["function_name"]})]
		result["feature_summary"] = "no_func"
		return result

	var fn: Dictionary = found["node"]
	result["function_found"] = true
	result["function_name"] = String(fn.get("name", spec["function_name"]))
	# ponytail: el tipo de retorno sale del qualType de la funcion
	# ("int (int)" -> "int"). Los parametros van aparte.
	var qual_type: String = String((fn.get("type", {}) as Dictionary).get("qualType", ""))
	var actual_return: String = qual_type
	var paren: int = qual_type.find(" (")
	if paren != -1:
		actual_return = qual_type.substr(0, paren)
	result["actual_return_type"] = actual_return
	var expected_return: String = String(spec["expected_return"])
	if expected_return.is_empty():
		result["return_type_match"] = not actual_return.is_empty()
	else:
		result["return_type_match"] = actual_return.find(expected_return) != -1

	var params: int = 0
	for child in fn.get("inner", []):
		if String((child as Dictionary).get("kind", "")) == "ParmVarDecl":
			params += 1
	result["param_count"] = params

	var body: Dictionary = _find_child(fn, "CompoundStmt")
	var scan: Dictionary = _scan(body)
	result["has_loop"] = bool(scan["loop"])
	result["has_conditional"] = bool(scan["conditional"])
	result["has_call"] = bool(scan["call"])
	result["has_return"] = bool(scan["return"])
	result["has_template"] = String(found["parent_kind"]) == "FunctionTemplateDecl"
	result["statement_count"] = int(scan["statements"])

	# Las features que el gate reconoce y el challenge pide.
	var missing: Array = []
	for feature in spec["required_features"]:
		if not _has_feature(String(feature), result):
			missing.append(String(feature))
	result["required_features_missing"] = missing

	var errors: Array = []
	if missing.size() > 0:
		errors.append(AST_VALID_LOOKUP_ERRORS["missing_features"].format({
			"features": ", ".join(missing),
		}))
	if not bool(result["return_type_match"]):
		errors.append(AST_VALID_LOOKUP_ERRORS["return_mismatch"].format({
			"expected": expected_return, "actual": actual_return,
		}))
	if int(result["statement_count"]) < int(spec["min_statements"]):
		errors.append(AST_VALID_LOOKUP_ERRORS["too_simple"].format({
			"min": spec["min_statements"], "actual": result["statement_count"],
		}))
	result["errors"] = errors

	# El mismo score que computaba la extension.
	var quality: float = 0.0
	if bool(result["function_found"]):
		quality = 0.4
		if bool(result["return_type_match"]):
			quality += 0.2
		if bool(result["has_return"]):
			quality += 0.1
		if bool(result["has_loop"]):
			quality += 0.15
		if bool(result["has_conditional"]):
			quality += 0.05
		if bool(result["has_call"]):
			quality += 0.05
		if int(result["statement_count"]) >= int(spec["min_statements"]):
			quality += 0.05
	result["quality"] = minf(quality, 1.0)
	result["valid"] = (
		missing.is_empty()
		and bool(result["return_type_match"])
		and int(result["statement_count"]) >= int(spec["min_statements"])
	)
	result["feature_summary"] = _summarize(result)
	return result


## Un resultado vacio, con la misma forma que el de la extension.
static func _blank(spec: Dictionary) -> Dictionary:
	return {
		"tree_parsed": false,
		"syntax_errors": false,
		"function_found": false,
		"function_name": "",
		"return_type_match": false,
		"actual_return_type": "",
		"param_count": 0,
		"statement_count": 0,
		"has_loop": false,
		"has_conditional": false,
		"has_call": false,
		"has_return": false,
		"has_template": false,
		"min_statements_required": int(spec["min_statements"]),
		"required_features_missing": [],
		"errors": [],
		"valid": false,
		"quality": 0.0,
		"feature_summary": "",
	}


## Saca del dump el objeto JSON de la funcion pedida.
##
## ponytail: con `-ast-dump-filter` clang emite un STREAM de objetos JSON
## (uno por nodo que matchea el filtro), no un solo documento: con el
## filtro "main" matchea funciones del SDK de macOS y el JSON queda
## partido. Los objetos son pretty-printed, asi que los de primer nivel
## arrancan con "{\n" en la columna 0 y cierran con "}\n" en la columna 0
## — y una cadena JSON nunca lleva un newline crudo, asi que ese recorte
## no puede cortar un string por la mitad.
static func _extract_function(raw: String, function_name: String) -> Dictionary:
	var marker: String = '"name": "%s"' % function_name
	var from: int = 0
	while true:
		var at: int = raw.find(marker, from)
		if at == -1:
			return {}
		from = at + marker.length()
		var start: int = raw.rfind("\n{\n", at)
		start = 0 if start == -1 else start + 1
		var end: int = raw.find("\n}\n", at)
		end = raw.length() if end == -1 else end + 2
		var parsed = JSON.parse_string(raw.substr(start, end - start))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var root: Dictionary = parsed
		var kind: String = String(root.get("kind", ""))
		if kind == "FunctionDecl" and String(root.get("name", "")) == function_name:
			return {"node": root, "parent_kind": ""}
		if kind == "FunctionTemplateDecl":
			var inner: Dictionary = _find_function(root, function_name, kind)
			if not inner.is_empty():
				return inner
	return {}


## Busca la funcion por nombre y devuelve su nodo y el kind de su padre
## (para saber si es una funcion template).
static func _find_function(node, name: String, parent_kind: String = "") -> Dictionary:
	if typeof(node) != TYPE_DICTIONARY:
		return {}
	var kind: String = String(node.get("kind", ""))
	if kind == "FunctionDecl" and String(node.get("name", "")) == name:
		return {"node": node, "parent_kind": parent_kind}
	for child in node.get("inner", []):
		var found: Dictionary = _find_function(child, name, kind)
		if not found.is_empty():
			return found
	return {}


## El primer hijo del kind pedido.
static func _find_child(node: Dictionary, kind: String) -> Dictionary:
	for child in node.get("inner", []):
		var child_dict: Dictionary = child
		if String(child_dict.get("kind", "")) == kind:
			return child_dict
	return {}


## Recorre el cuerpo contando statements y buscando las estructuras.
static func _scan(node: Dictionary) -> Dictionary:
	var found := {
		"loop": false,
		"conditional": false,
		"call": false,
		"return": false,
		"statements": 0,
	}
	# El cuerpo de la funcion ES un CompoundStmt: sus hijos directos son
	# sentencias (o expresiones sueltas, que tambien cuentan).
	_scan_into(node, found, "CompoundStmt")
	return found


static func _scan_into(node: Dictionary, found: Dictionary, parent_kind: String = "") -> void:
	for child in node.get("inner", []):
		var child_dict: Dictionary = child
		var kind: String = String(child_dict.get("kind", ""))
		if kind in STATEMENT_KINDS:
			found["statements"] = int(found["statements"]) + 1
		elif parent_kind == "CompoundStmt" and kind != "None":
			# ponytail: clang NO envuelve una sentencia de expresion en un
			# nodo: `a = b;` es un CompoundStmt con un BinaryOperator
			# adentro. tree-sitter si lo cuenta, asi que se cuenta aca: una
			# expresion que es hija directa de un bloque es una sentencia.
			found["statements"] = int(found["statements"]) + 1
		if kind in LOOP_KINDS:
			found["loop"] = true
		elif kind == "IfStmt":
			found["conditional"] = true
		elif kind in CALL_KINDS:
			found["call"] = true
		elif kind == "ReturnStmt":
			found["return"] = true
		_scan_into(child_dict, found, kind)


## El gate reconoce un conjunto cerrado de features. Una feature con un
## nombre que el gate no conoce hace el challenge IMPOSIBLE.
static func _has_feature(feature: String, result: Dictionary) -> bool:
	match feature:
		"loop":
			return bool(result["has_loop"])
		"conditional", "if":
			return bool(result["has_conditional"])
		"call":
			return bool(result["has_call"])
		"return":
			return bool(result["has_return"])
		"template":
			return bool(result["has_template"])
	return false


## Los errores de clang, sin la ruta del temporal.
static func _clang_errors(log_text: String, dir: String) -> Array:
	var out: Array = []
	var clean: String = log_text.replace(dir + "/", "") if not dir.is_empty() else log_text
	for line in clean.split("\n"):
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		if text.contains("error:"):
			out.append(text)
	if out.is_empty():
		out.append(AST_VALID_LOOKUP_ERRORS["syntax_error"])
	return out


static func _shell_quote(value: String) -> String:
	return "'" + value.replace("'", "'\\''") + "'"


# Best-effort extraction of the return-type token from a signature like
# "vector<int> bubbleSort(vector<int> arr)" → "vector<int>".
# We use the first whitespace-separated token, which matches "int", "bool",
# "void", "vector<int>", etc.
static func _extract_return_token(signature: String) -> String:
	var sig := signature.strip_edges()
	if sig.is_empty():
		return ""
	var space := sig.find(" ")
	if space == -1:
		return sig
	return sig.substr(0, space)


# Returns a one-line human-readable summary for the BattleTerminal.
static func _summarize(ast: Dictionary) -> String:
	if not bool(ast.get("function_found", false)):
		return "no_func"
	var parts: PackedStringArray = PackedStringArray()
	parts.append("fn")
	if bool(ast.get("return_type_match", false)):
		parts.append("ret")
	if bool(ast.get("has_loop", false)):
		parts.append("loop")
	if bool(ast.get("has_conditional", false)):
		parts.append("cond")
	if bool(ast.get("has_call", false)):
		parts.append("call")
	if bool(ast.get("has_return", false)):
		parts.append("return")
	parts.append("stmts=%d" % int(ast.get("statement_count", 0)))
	return ",".join(parts)

# Maps GDScript errors back to friendly lines for the BattleTerminal log.
static func friendly_errors(ast: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Array = ast.get("errors", [])
	if raw.size() == 0:
		return out
	for msg in raw:
		out.append(String(msg))
	return out


## Los nombres que el gate de forma reconoce y como se le dicen al
## jugador.
##
## ponytail: el vocabulario esta en `_has_feature` (aca) y no en un
## validador de C++: un challenge que pide una feature con un nombre que
## el gate no conoce —"if" en vez de "conditional"— es IMPOSIBLE: el gate
## la pide igual, no la encuentra nunca y el challenge no se puede ganar.
## `challenge_gate_guard.gd` prueba que todo challenge es ganable.
const FEATURE_LABELS: Dictionary = {
	"loop": "un bucle (for/while)",
	"conditional": "una condición (if/else)",
	"return": "un return",
	"call": "una llamada a función",
	"template": "una función template",
}

## Que estructuras del AST satisface el codigo, por nombre de feature.
static func feature_status(ast: Dictionary) -> Dictionary:
	return {
		"loop": bool(ast.get("has_loop", false)),
		"conditional": bool(ast.get("has_conditional", false)),
		"return": bool(ast.get("has_return", false)),
		"call": bool(ast.get("has_call", false)),
		"template": bool(ast.get("has_template", false)),
	}

## Como se le dice al jugador una feature del vocabulario.
static func feature_label(feature: String) -> String:
	return String(FEATURE_LABELS.get(feature, feature))


## El error de features en el idioma del jugador.
##
## ponytail: "Missing required features: if." no le dice nada a un jugador
## que no sabe el vocabulario del analizador. El editor ya muestra el
## checklist con el tick en vivo; este mensaje es el mismo dato en texto.
static func missing_features_message(missing: Array) -> String:
	if missing.is_empty():
		return ""
	var labels: Array[String] = []
	for feature in missing:
		labels.append(feature_label(String(feature)))
	return "Te falta: %s." % ", ".join(labels)
