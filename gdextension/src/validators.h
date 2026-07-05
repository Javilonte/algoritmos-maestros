#ifndef VALIDATORS_H
#define VALIDATORS_H

#include <tree_sitter/api.h>

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {
namespace validators {

// Looks up challenge_id in the validator registry and runs the matching
// check against the parsed tree. Returns {"success": false, "message":
// "Unknown challenge '<id>'."} if no validator is registered for the id.
Dictionary run(const String &challenge_id, TSTree *tree, const String &code);

// Dynamic structural validation. `structure_spec` is a Dictionary with:
//   - "function_name"      (String) required function name
//   - "expected_return"    (String, optional) substring that the return-type
//                            token must contain (e.g. "int", "vector", "bool")
//   - "min_statements"     (int, optional, default 1) minimum non-trivial
//                            statements in the function body
//   - "required_features"  (Array of String, optional) — any of:
//                            "loop", "conditional", "call", "return"
// Returns a Dictionary with structural metrics that GDScript combines
// with the oracle test results to compute damage tier.
Dictionary validate_structure(TSTree *tree, const String &code, const Dictionary &structure_spec);

}
}

#endif
