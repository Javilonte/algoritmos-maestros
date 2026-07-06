#ifndef COMBAT_ALGORITHM_EVALUATOR_H
#define COMBAT_ALGORITHM_EVALUATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>
#include <string>

namespace godot {

// CombatAlgorithmEvaluator
//
// Native C++ class exposed to Godot via GDExtension. Receives the player's
// source code as a Godot String, runs a safe in-process evaluation of the
// algorithm's structural complexity (using the existing TreeSitterParser for
// AST validation), and emits a Dictionary describing the combat outcome:
//
//   {
//     "success":        bool,    // false on compile / structural error
//     "damage":         int,     // 0 if !success
//     "complexity":     String,  // e.g. "O(n)", "O(n^2)"
//     "tier":           String,  // S / A / B / C / D / X
//     "evaluation_ms":  int,     // wall-clock time of evaluation
//     "error_message":  String,  // empty if success
//     "error_line":     int,     // -1 if no line info
//     "challenge_id":   String,
//     "function_count": int,
//     "loop_depth":     int,
//   }
//
// Memory ownership: this class holds NO references to Godot objects other
// than the ones returned through the Dictionary (String, Dictionary, Array
// — all value types or RefCounted managed by godot-cpp). No raw pointers are
// retained across method boundaries. All std::string instances created from
// Godot Strings are stack-local and destroyed before the function returns.
class CombatAlgorithmEvaluator : public RefCounted {
	GDCLASS(CombatAlgorithmEvaluator, RefCounted)

private:
	// Configuration constants. Stored as members so tests can monkey-patch.
	int32_t base_damage = 25;
	int32_t crit_multiplier = 2;
	int32_t time_budget_ms = 5000;

	// Per-challenge complexity expectations. Key = challenge_id,
	// Value = Dictionary { "expected": "O(n)", "tolerance_ms": int }.
	Dictionary challenge_profiles;

	void _ensure_default_profiles();

	// Safe string conversions: String -> std::string. Returns owned heap
	// buffer only used within the function scope; caller MUST NOT store.
	std::string _to_std_string(const String &p_godot_str) const;

	// Pure functions over a std::string view. No allocations beyond the
	// returned Dictionary.
	int _count_function_definitions(const std::string &p_source) const;
	int _max_loop_nesting(const std::string &p_source) const;
	bool _contains_recursion(const std::string &p_source, const std::string &p_function_name) const;

	// Returns one of: "O(1)", "O(log n)", "O(n)", "O(n log n)", "O(n^2)",
	// "O(n^3)", "O(2^n)".
	String _infer_complexity(const std::string &p_source, int p_function_count, int p_loop_depth) const;

	// Tier assignment based on complexity vs expected for the challenge.
	String _tier_for_complexity(const String &p_expected, const String &p_actual) const;

	// Damage formula. Pure: returns int only.
	int _compute_damage(const String &p_tier, int64_t p_eval_ms) const;

protected:
	static void _bind_methods();

public:
	CombatAlgorithmEvaluator();
	~CombatAlgorithmEvaluator();

	// Main API. Returns Dictionary (see class comment for shape).
	Dictionary evaluate(const String &p_code, const String &p_challenge_id);

	// Async-friendly variant. Emits the signal `evaluation_complete` and
	// returns immediately with the assigned evaluation_id. Listeners should
	// connect to the signal to receive results. Thread-safe; the heavy work
	// runs on a worker thread internally but signals fire on the main thread.
	Dictionary evaluate_async(const String &p_code, const String &p_challenge_id);

	// Configuration setters (exposed to GDScript).
	void set_base_damage(int32_t p_value);
	int32_t get_base_damage() const;

	void set_crit_multiplier(int32_t p_value);
	int32_t get_crit_multiplier() const;

	void set_time_budget_ms(int32_t p_value);
	int32_t get_time_budget_ms() const;

	void set_challenge_profile(const String &p_challenge_id, const Dictionary &p_profile);
};

}  // namespace godot

#endif  // COMBAT_ALGORITHM_EVALUATOR_H