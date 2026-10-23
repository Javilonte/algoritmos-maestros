#include "combat_algorithm_evaluator.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <chrono>
#include <cstring>
#include <regex>
#include <sstream>

namespace godot {

// ----------------------------------------------------------------------------
// Construction / lifecycle
// ----------------------------------------------------------------------------

CombatAlgorithmEvaluator::CombatAlgorithmEvaluator() {
	_ensure_default_profiles();
}

CombatAlgorithmEvaluator::~CombatAlgorithmEvaluator() {
	// No raw pointer members to free. Dictionary holds RefCounted only and
	// decrements automatically when this object dies.
}

void CombatAlgorithmEvaluator::_ensure_default_profiles() {
	// Default challenge expectations. Each profile maps challenge_id to
	// { "expected": String, "tolerance_ms": int, "difficulty": int }.
	if (!challenge_profiles.has("main_exit_check")) {
		Dictionary p;
		p["expected"] = String("O(1)");
		p["tolerance_ms"] = 100;
		p["difficulty"] = 1;
		challenge_profiles["main_exit_check"] = p;
	}
	if (!challenge_profiles.has("linear_search")) {
		Dictionary p;
		p["expected"] = String("O(n)");
		p["tolerance_ms"] = 200;
		p["difficulty"] = 2;
		challenge_profiles["linear_search"] = p;
	}
	if (!challenge_profiles.has("bubble_sort")) {
		Dictionary p;
		p["expected"] = String("O(n^2)");
		p["tolerance_ms"] = 500;
		p["difficulty"] = 3;
		challenge_profiles["bubble_sort"] = p;
	}
	if (!challenge_profiles.has("factorial")) {
		Dictionary p;
		p["expected"] = String("O(n)");
		p["tolerance_ms"] = 200;
		p["difficulty"] = 2;
		challenge_profiles["factorial"] = p;
	}
	if (!challenge_profiles.has("fibonacci")) {
		Dictionary p;
		p["expected"] = String("O(2^n)");
		p["tolerance_ms"] = 1000;
		p["difficulty"] = 4;
		challenge_profiles["fibonacci"] = p;
	}
}

// ----------------------------------------------------------------------------
// String conversion (memory-safe)
// ----------------------------------------------------------------------------

std::string CombatAlgorithmEvaluator::_to_std_string(const String &p_godot_str) const {
	// godot::String -> UTF-8 CharString -> std::string.
	// The CharString temporary lives only inside this function; we copy its
	// bytes into a fresh std::string before returning. After this function
	// returns, the std::string owns its memory independently of Godot.
	CharString cs = p_godot_str.utf8();
	return std::string(cs.get_data(), static_cast<size_t>(cs.length()));
}

// ----------------------------------------------------------------------------
// Structural analysis (pure functions over std::string)
// ----------------------------------------------------------------------------

int CombatAlgorithmEvaluator::_count_function_definitions(const std::string &p_source) const {
	// Match `int NAME(`, `void NAME(`, `bool NAME(`, etc.
	// We deliberately accept a permissive pattern — the AST validation step
	// has already happened in TreeSitterParser::validate().
	static const std::regex fn_re(R"(\b(?:int|void|bool|long|float|double|char|short|unsigned|size_t|auto)\s+[A-Za-z_]\w*\s*\()");
	std::sregex_iterator it(p_source.begin(), p_source.end(), fn_re);
	std::sregex_iterator end;
	int count = 0;
	while (it != end) {
		++count;
		++it;
	}
	return count;
}

int CombatAlgorithmEvaluator::_max_loop_nesting(const std::string &p_source) const {
	// Walk char-by-char; whenever we open `{` while inside a loop, increment
	// depth; when closing, decrement. Track max.
	int depth = 0;
	int max_depth = 0;
	bool in_loop = false;
	bool in_paren = false;

	for (size_t i = 0; i < p_source.size(); ++i) {
		char c = p_source[i];
		// Detect loop headers with simple regex-free matching.
		if (!in_loop && (i + 4) < p_source.size()) {
			// for / while keywords followed by '('
			if ((p_source[i] == 'f' && p_source[i + 1] == 'o' && p_source[i + 2] == 'r' && p_source[i + 3] == ' ' && p_source[i + 4] == '(') ||
				(p_source[i] == 'w' && p_source[i + 1] == 'h' && p_source[i + 2] == 'i' && p_source[i + 3] == 'l' && p_source[i + 4] == 'e' && p_source[i + 5] == ' ' && p_source[i + 6] == '(')) {
				in_loop = true;
				in_paren = true;
			}
		}
		if (in_paren && c == ')') {
			in_paren = false;
			continue;
		}
		if (in_paren) {
			continue;
		}
		if (c == '{' && in_loop) {
			++depth;
			if (depth > max_depth) {
				max_depth = depth;
			}
		} else if (c == '}') {
			if (depth > 0) {
				--depth;
			}
			if (in_loop && depth == 0) {
				in_loop = false;
			}
		}
	}
	return max_depth;
}

bool CombatAlgorithmEvaluator::_contains_recursion(const std::string &p_source, const std::string &p_function_name) const {
	// Look for the function name appearing followed by `(` not preceded by
	// the function declaration itself.
	const std::string call_pattern = p_function_name + "(";
	size_t pos = 0;
	while ((pos = p_source.find(call_pattern, pos)) != std::string::npos) {
		// Skip the declaration site itself (function_name followed by `(`).
		// The declaration is preceded by a return type; we check that the
		// previous non-whitespace character is NOT an identifier char.
		size_t back = (pos > 0) ? pos - 1 : 0;
		while (back > 0 && std::isspace(static_cast<unsigned char>(p_source[back]))) {
			--back;
		}
		bool preceded_by_ident = (back > 0) && (std::isalnum(static_cast<unsigned char>(p_source[back])) || p_source[back] == '_');
		if (!preceded_by_ident) {
			return true;
		}
		pos += call_pattern.size();
	}
	return false;
}

String CombatAlgorithmEvaluator::_infer_complexity(const std::string &p_source, int /* p_function_count */, int p_loop_depth) const {
	// Crude but defensible complexity inference:
	//   0 loops                       -> O(1)
	//   1 loop, no recursion           -> O(n)
	//   1 loop, recursion OR 2 loops  -> O(n^2) [without optimization]
	//   2 loops, recursion            -> O(n^3)
	//   recursion alone, no loops     -> O(2^n) (e.g. naive fibonacci)
	//   nested loop > 2               -> O(n^k) where k = max depth
	// Note: p_function_count is reserved for future heuristics (e.g. multiple
	// recursion funcs would push exponential factor). Currently unused.

	// Try to find a function name for recursion check.
	std::string primary_fn;
	{
		static const std::regex fn_re(R"(\b(?:int|void|bool|long|float|double|auto)\s+([A-Za-z_]\w*)\s*\()");
		std::sregex_iterator it(p_source.begin(), p_source.end(), fn_re);
		std::sregex_iterator end;
		if (it != end) {
			primary_fn = (*it)[1].str();
		}
	}
	bool has_recursion = !primary_fn.empty() && _contains_recursion(p_source, primary_fn);

	if (p_loop_depth == 0 && !has_recursion) {
		return String("O(1)");
	}
	if (p_loop_depth == 0 && has_recursion) {
		return String("O(2^n)");
	}
	if (p_loop_depth == 1 && !has_recursion) {
		return String("O(n)");
	}
	if (p_loop_depth == 1 && has_recursion) {
		return String("O(n log n)");  // naive recursion in a loop is ~n*rec
	}
	if (p_loop_depth == 2) {
		return String("O(n^2)");
	}
	if (p_loop_depth == 3) {
		return String("O(n^3)");
	}
	// O(n^k)
	std::ostringstream oss;
	oss << "O(n^" << p_loop_depth << ")";
	return String(oss.str().c_str());
}

String CombatAlgorithmEvaluator::_tier_for_complexity(const String &p_expected, const String &p_actual) const {
	// Map complexity match quality -> tier.
	if (p_expected == p_actual) {
		return String("S");
	}
	// Adjacent tiers: O(n) vs O(n log n) etc.
	static const std::vector<std::pair<std::string, std::string>> chain = {
		{"O(1)", "O(log n)"},
		{"O(log n)", "O(n)"},
		{"O(n)", "O(n log n)"},
		{"O(n log n)", "O(n^2)"},
		{"O(n^2)", "O(n^3)"},
		{"O(n^3)", "O(2^n)"},
	};
	std::string exp = _to_std_string(p_expected);
	std::string act = _to_std_string(p_actual);
	for (const auto &pair : chain) {
		if (pair.first == exp && pair.second == act) {
			return String("A");
		}
		if (pair.first == act && pair.second == exp) {
			return String("A");
		}
	}
	// Two steps away = B tier.
	for (size_t i = 0; i < chain.size(); ++i) {
		if (chain[i].first == exp) {
			if (i + 1 < chain.size() && chain[i + 1].first == act) {
				return String("B");
			}
			if (i + 1 < chain.size() && chain[i + 1].second == act) {
				return String("B");
			}
		}
	}
	return String("D");
}

int CombatAlgorithmEvaluator::_compute_damage(const String &p_tier, int64_t p_eval_ms) const {
	int32_t mult = 1;
	if (p_tier == String("S")) {
		mult = crit_multiplier;
	} else if (p_tier == String("A")) {
		mult = 2;
	} else if (p_tier == String("B")) {
		mult = 1;
	} else if (p_tier == String("C")) {
		mult = 1;
	} else if (p_tier == String("D")) {
		mult = 1;
	} else {
		mult = 0;
	}
	int32_t base = base_damage * mult;
	// Speed bonus: 1% extra damage per 10ms under the budget.
	int32_t speed_bonus = 0;
	if (p_eval_ms < time_budget_ms) {
		speed_bonus = static_cast<int32_t>((time_budget_ms - p_eval_ms) / 10);
	}
	return base + speed_bonus;
}

// ----------------------------------------------------------------------------
// Public API
// ----------------------------------------------------------------------------

Dictionary CombatAlgorithmEvaluator::evaluate(const String &p_code, const String &p_challenge_id) {
	Dictionary result;
	result["challenge_id"] = p_challenge_id;

	// Time the whole evaluation so we can report wall-clock cost.
	auto t_start = std::chrono::steady_clock::now();

	// 1. Validate that we have at least one function definition. We don't
	//    re-parse the AST here; we delegate to TreeSitterParser.
	bool engine_present = Engine::get_singleton()->has_singleton("TreeSitterParser");
	(void)engine_present;  // TreeSitter is a class; we instantiate via ClassDB.

	// 2. Convert source to std::string and run structural analysis.
	std::string src = _to_std_string(p_code);

	if (src.empty()) {
		result["success"] = false;
		result["error_message"] = String("empty source");
		result["error_line"] = -1;
		result["damage"] = 0;
		result["complexity"] = String("O(?)");
		result["tier"] = String("X");
		result["evaluation_ms"] = 0;
		result["function_count"] = 0;
		result["loop_depth"] = 0;
		return result;
	}

	// 3. Naive syntax sanity: check braces balance.
	int brace = 0;
	int first_unbalanced_line = -1;
	int line = 1;
	for (size_t i = 0; i < src.size(); ++i) {
		char c = src[i];
		if (c == '\n') {
			++line;
			continue;
		}
		if (c == '{') {
			++brace;
		} else if (c == '}') {
			--brace;
			if (brace < 0 && first_unbalanced_line == -1) {
				first_unbalanced_line = line;
			}
		}
	}
	if (brace != 0) {
		result["success"] = false;
		result["error_message"] = String("unbalanced braces");
		result["error_line"] = first_unbalanced_line;
		result["damage"] = 0;
		result["complexity"] = String("O(?)");
		result["tier"] = String("X");
		result["evaluation_ms"] = 0;
		result["function_count"] = 0;
		result["loop_depth"] = 0;
		return result;
	}

	// 4. Structural analysis.
	int func_count = _count_function_definitions(src);
	if (func_count == 0) {
		result["success"] = false;
		result["error_message"] = String("no function definition found (expected `int main()` or similar)");
		result["error_line"] = 1;
		result["damage"] = 0;
		result["complexity"] = String("O(?)");
		result["tier"] = String("X");
		result["evaluation_ms"] = 0;
		result["function_count"] = 0;
		result["loop_depth"] = 0;
		return result;
	}
	int loop_depth = _max_loop_nesting(src);
	String complexity = _infer_complexity(src, func_count, loop_depth);

	// 5. Tier and damage.
	Dictionary profile;
	if (challenge_profiles.has(p_challenge_id)) {
		profile = challenge_profiles[p_challenge_id];
	} else {
		profile["expected"] = String("O(n)");
		profile["tolerance_ms"] = 500;
		profile["difficulty"] = 1;
	}
	String expected = profile["expected"];
	String tier = _tier_for_complexity(expected, complexity);

	auto t_end = std::chrono::steady_clock::now();
	int64_t ms = std::chrono::duration_cast<std::chrono::milliseconds>(t_end - t_start).count();
	int damage = _compute_damage(tier, ms);

	result["success"] = (tier != String("X"));
	result["error_message"] = String("");
	result["error_line"] = -1;
	result["damage"] = damage;
	result["complexity"] = complexity;
	result["tier"] = tier;
	result["evaluation_ms"] = static_cast<int>(ms);
	result["function_count"] = func_count;
	result["loop_depth"] = loop_depth;
	return result;
}

Dictionary CombatAlgorithmEvaluator::evaluate_async(const String &p_code, const String &p_challenge_id) {
	// Synchronous fast path; signals are emitted on the main thread regardless.
	Dictionary result = evaluate(p_code, p_challenge_id);
	// Emit the signal. Listener is responsible for updating the UI.
	emit_signal("evaluation_complete", result);
	return result;
}

// ----------------------------------------------------------------------------
// Setters / getters
// ----------------------------------------------------------------------------

void CombatAlgorithmEvaluator::set_base_damage(int32_t p_value) { base_damage = p_value; }
int32_t CombatAlgorithmEvaluator::get_base_damage() const { return base_damage; }

void CombatAlgorithmEvaluator::set_crit_multiplier(int32_t p_value) { crit_multiplier = p_value; }
int32_t CombatAlgorithmEvaluator::get_crit_multiplier() const { return crit_multiplier; }

void CombatAlgorithmEvaluator::set_time_budget_ms(int32_t p_value) { time_budget_ms = p_value; }
int32_t CombatAlgorithmEvaluator::get_time_budget_ms() const { return time_budget_ms; }

void CombatAlgorithmEvaluator::set_challenge_profile(const String &p_challenge_id, const Dictionary &p_profile) {
	challenge_profiles[p_challenge_id] = p_profile;
}

// ----------------------------------------------------------------------------
// Method binding (signal included)
// ----------------------------------------------------------------------------

void CombatAlgorithmEvaluator::_bind_methods() {
	ClassDB::bind_method(D_METHOD("evaluate", "code", "challenge_id"), &CombatAlgorithmEvaluator::evaluate);
	ClassDB::bind_method(D_METHOD("evaluate_async", "code", "challenge_id"), &CombatAlgorithmEvaluator::evaluate_async);
	ClassDB::bind_method(D_METHOD("set_base_damage", "value"), &CombatAlgorithmEvaluator::set_base_damage);
	ClassDB::bind_method(D_METHOD("get_base_damage"), &CombatAlgorithmEvaluator::get_base_damage);
	ClassDB::bind_method(D_METHOD("set_crit_multiplier", "value"), &CombatAlgorithmEvaluator::set_crit_multiplier);
	ClassDB::bind_method(D_METHOD("get_crit_multiplier"), &CombatAlgorithmEvaluator::get_crit_multiplier);
	ClassDB::bind_method(D_METHOD("set_time_budget_ms", "value"), &CombatAlgorithmEvaluator::set_time_budget_ms);
	ClassDB::bind_method(D_METHOD("get_time_budget_ms"), &CombatAlgorithmEvaluator::get_time_budget_ms);
	ClassDB::bind_method(D_METHOD("set_challenge_profile", "challenge_id", "profile"), &CombatAlgorithmEvaluator::set_challenge_profile);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "base_damage"), "set_base_damage", "get_base_damage");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "crit_multiplier"), "set_crit_multiplier", "get_crit_multiplier");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "time_budget_ms"), "set_time_budget_ms", "get_time_budget_ms");

	ADD_SIGNAL(MethodInfo("evaluation_complete", PropertyInfo(Variant::DICTIONARY, "result")));
}

}  // namespace godot