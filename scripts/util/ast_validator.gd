class_name AstValidator
extends RefCounted

# Wraps the TreeSitterParser.validate_structure() method exposed by the
# algorithm-validator GDExtension. Bridges the C++ AST walk to GDScript
# via a Dictionary spec that mirrors ChallengeResource fields.

const AST_VALID_LOOKUP_ERRORS := {
	"missing_function": "Function '{expected}' was not declared.",
	"return_mismatch": "Return type did not contain '{expected}'. Got '{actual}'.",
	"missing_features": "Missing required feature(s): {features}.",
	"too_simple": "Function body too simple: need at least {min} statement(s), got {actual}.",
	"syntax_error": "Syntax error: code did not parse as valid C++.",
}

# Builds a structure_spec Dictionary from a ChallengeResource.
static func build_spec_from_challenge(challenge: ChallengeResource) -> Dictionary:
	var spec := {
		"function_name": String(challenge.function_name_hint),
		"expected_return": _extract_return_token(String(challenge.function_signature)),
		"min_statements": int(challenge.ast_min_statements) if int(challenge.ast_min_statements) > 0 else 1,
		"required_features": Array(challenge.ast_required_features),
	}
	return spec

# Calls the C++ validator. Returns the structured Dictionary unchanged so
# downstream code can inspect metrics (quality, statement_count, etc.).
static func validate(code: String, challenge: ChallengeResource) -> Dictionary:
	var parser = ClassDB.instantiate("TreeSitterParser") if ClassDB.class_exists("TreeSitterParser") else null
	if parser == null:
		return {
			"valid": false,
			"quality": 0.0,
			"errors": ["AST validator not available (TreeSitterParser missing)."],
			"function_found": false,
			"feature_summary": "",
		}
	var spec := build_spec_from_challenge(challenge)
	var ast_dict: Dictionary = parser.validate_structure(code, spec)
	ast_dict["feature_summary"] = _summarize(ast_dict)
	return ast_dict

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
## ponytail: el vocabulario vive en el validador de C++
## (gdextension/src/validators.cpp: _check_required_feature) y recognizes
## only loop, conditional, call and return. A challenge asking for "if" is
## IMPOSSIBLE: the gate looks for a feature whose name it does not know.
## `challenge_gate_guard.gd` proves every challenge is winnable.
const FEATURE_LABELS: Dictionary = {
	"loop": "un bucle (for/while)",
	"conditional": "una condición (if/else)",
	"return": "un return",
	"call": "una llamada a función",
}

## Que estructuras del AST satisface el codigo, por nombre de feature.
static func feature_status(ast: Dictionary) -> Dictionary:
	return {
		"loop": bool(ast.get("has_loop", false)),
		"conditional": bool(ast.get("has_conditional", false)),
		"return": bool(ast.get("has_return", false)),
		"call": bool(ast.get("has_call", false)),
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
