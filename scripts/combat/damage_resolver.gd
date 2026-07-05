extends RefCounted
class_name DamageResolver

## Calcula el daño infligido al enemigo basándose en:
## - Resultado del sandbox (compiló? cuánto tardó? memoria usada?)
## - Tiempo restante en el timer del jugador
## - Elemento/vulnerabilidad del enemigo (reglas del skill tree)
## - Macros del jugador (multiplicadores de daño)
##
## Fórmula base:
##   damage = base_score * time_bonus * element_multiplier * macro_multiplier
##
##   - base_score = resultado del sandbox (calidad del código)
##   - time_bonus = 1.0 + (time_left / 30.0) * 0.5  [rango 1.0 .. 1.5]
##   - element_multiplier = lookup según keyword usada y debilidad del enemigo
##   - macro_multiplier = bonus si el jugador insertó macros conocidas
##   - Si offline: x0.5 al daño final.

const BASE_ARITH: int = 10
const BASE_CTRL: int = 15
const BASE_PTR: int = 25
const BASE_RECURSION: int = 35
const BASE_TEMPLATE: int = 30
const BASE_STL: int = 20
const BASE_THREAD: int = 40
const BASE_FULL_INCLUDE: int = 60

## Calcula daño. Devuelve dict con damage desglosado.
static func compute(
	result: Dictionary,
	time_left: float,
	enemy: Dictionary,
	used_macros: Array[String] = []
) -> Dictionary:
	var compiled: bool = result.get("compiled", false)
	if not compiled:
		return {
			"damage": 0,
			"crit": false,
			"element": "none",
			"breakdown": {"error": String(result.get("stderr", result.get("compile_message", "compile error")))},
		}
	var code: String = String(result.get("source_code", ""))
	var matches: bool = bool(result.get("matches_expected", compiled))
	var sandbox_score: int = int(result.get("score", 0))
	var keyword_score := _base_score_from_keywords(code)
	var base := sandbox_score if matches else keyword_score
	var element := _detect_element(code)
	var element_mult := float(enemy.get("element_weaknesses", {}).get(element, 1.0))
	var time_bonus := 1.0 + clampf(time_left / 30.0, 0.0, 1.0) * 0.5
	var macro_mult := _macro_multiplier(used_macros)
	var offline_mult := 0.5 if result.get("offline", false) else 1.0
	var raw := float(base) * time_bonus * element_mult * macro_mult * offline_mult
	var crit := element_mult >= 2.0
	var damage := int(round(raw * (2.0 if crit else 1.0)))
	if not matches:
		damage = int(damage * 0.3)
	return {
		"damage": damage,
		"crit": crit,
		"element": element,
		"breakdown": {
			"base": base,
			"sandbox_score": sandbox_score,
			"matches_expected": matches,
			"time_bonus": snappedf(time_bonus, 0.01),
			"element_mult": element_mult,
			"macro_mult": macro_mult,
			"offline_mult": offline_mult,
			"raw": snappedf(raw, 0.1),
		},
	}

static func _base_score_from_keywords(code: String) -> int:
	var score := 0
	if code.contains("malloc") or code.contains("free") or code.contains("delete") or code.contains("new "):
		score = max(score, BASE_PTR)
	if code.contains("template") or code.contains("<T>"):
		score = max(score, BASE_TEMPLATE)
	if code.contains("std::") or code.contains("vector") or code.contains("sort") or code.contains("algorithm"):
		score = max(score, BASE_STL)
	if code.contains("thread") or code.contains("async"):
		score = max(score, BASE_THREAD)
	if code.contains("return ") and code.contains("(") and _looks_recursive(code):
		score = max(score, BASE_RECURSION)
	if code.contains("for") or code.contains("while"):
		score = max(score, BASE_CTRL)
	if code.contains("if") and code.contains("else"):
		score = max(score, BASE_CTRL)
	if code.contains("#include") and code.contains("bits/stdc++.h"):
		score = max(score, BASE_FULL_INCLUDE)
	if score == 0:
		score = BASE_ARITH
	return score

static func _detect_element(code: String) -> String:
	if code.contains("malloc") or code.contains("free") or code.contains("delete"):
		return "pointer"
	if code.contains("std::") or code.contains("vector") or code.contains("sort"):
		return "stl"
	if code.contains("thread") or code.contains("async"):
		return "concurrency"
	if code.contains("template"):
		return "template"
	if code.contains("for") or code.contains("while") or code.contains("if"):
		return "control_flow"
	return "arithmetic"

static func _looks_recursive(code: String) -> bool:
	## Heurística simple: la función se llama a sí misma con un parámetro distinto.
	var func_match := RegEx.new()
	func_match.compile("(\\w+)\\s*\\([^)]*\\w+[^)]*\\)\\s*\\{[^}]*\\1\\s*\\(")
	return func_match.search(code) != null

static func _macro_multiplier(used: Array[String]) -> float:
	var mult := 1.0
	for m in used:
		match m:
			"crit": mult += 0.3
			"loop": mult += 0.2
			"free": mult += 0.4
			"sort": mult += 0.25
			"dmg1": mult += 0.1
	mult = clampf(mult, 1.0, 2.0)
	return mult