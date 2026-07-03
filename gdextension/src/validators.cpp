#include "validators.h"

#include <tree_sitter/api.h>

#include <functional>
#include <string>
#include <unordered_map>

#include <godot_cpp/variant/variant.hpp>

#include "ast_utils.h"

namespace godot {
namespace validators {

namespace {

using ValidatorFn = std::function<Dictionary(TSTree *, const String &)>;

Dictionary validate_main_exit(TSTree *tree, const String &code) {
	Dictionary result;
	TSNode root = ts_tree_root_node(tree);

	if (ts_node_has_error(root)) {
		result["success"] = false;
		result["message"] = "Syntax error: your code contains invalid C++.";
		return result;
	}

	TSNode func_def = ast_utils::find_child(root, "function_definition");
	if (ts_node_is_null(func_def)) {
		result["success"] = false;
		result["message"] = "No function definition found. Expected: 'int main() { ... }'.";
		return result;
	}

	TSNode ret_type = ast_utils::find_child(func_def, "primitive_type");
	if (ts_node_is_null(ret_type) || ast_utils::node_text(ret_type, code) != "int") {
		result["success"] = false;
		result["message"] = "Function must return 'int'.";
		return result;
	}

	TSNode declarator = ast_utils::find_child(func_def, "function_declarator");
	if (!ts_node_is_null(declarator)) {
		TSNode id_node = ast_utils::find_child(declarator, "identifier");
		if (!ts_node_is_null(id_node) && ast_utils::node_text(id_node, code) != "main") {
			result["success"] = false;
			result["message"] = "Expected function named 'main', got '" + ast_utils::node_text(id_node, code) + "'.";
			return result;
		}
	}

	if (!ast_utils::returns_literal_zero(func_def, code)) {
		if (ast_utils::has_descendant_of_type(func_def, "return_statement")) {
			result["success"] = false;
			result["message"] = "Function must 'return 0' (only 0 is accepted).";
		} else {
			result["success"] = false;
			result["message"] = "Function body must contain a 'return' statement.";
		}
		return result;
	}

	result["success"] = true;
	result["message"] = "C++ syntax validated. Algorithm accepted!";
	return result;
}

const std::unordered_map<std::string, ValidatorFn> &registry() {
	static const std::unordered_map<std::string, ValidatorFn> table = {
		{ "main_exit_check", validate_main_exit },
	};
	return table;
}

// === Dynamic structural validation (Phase 2) ===

bool _check_required_feature(const String &feature, TSNode func_def) {
	if (feature == "loop") {
		return ast_utils::function_has_loop(func_def);
	}
	if (feature == "conditional") {
		return ast_utils::function_has_conditional(func_def);
	}
	if (feature == "call") {
		return ast_utils::function_has_call(func_def);
	}
	if (feature == "return") {
		return ast_utils::function_has_return(func_def);
	}
	return false;
}

} // namespace

Dictionary run(const String &challenge_id, TSTree *tree, const String &code) {
	std::string key = challenge_id.utf8().get_data();
	const auto &table = registry();
	auto it = table.find(key);
	if (it == table.end()) {
		Dictionary result;
		result["success"] = false;
		result["message"] = "Unknown challenge '" + challenge_id + "'.";
		return result;
	}
	return it->second(tree, code);
}

Dictionary validate_structure(TSTree *tree, const String &code, const Dictionary &structure_spec) {
	Dictionary result;
	TSNode root = ts_tree_root_node(tree);

	// Always reflect the AST-level state first
	result["tree_parsed"] = !ts_node_is_null(root) && !ts_node_has_error(root);
	result["syntax_errors"] = ts_node_has_error(root);
	result["function_found"] = false;
	result["function_name"] = "";
	result["return_type_match"] = false;
	result["actual_return_type"] = "";
	result["param_count"] = 0;
	result["statement_count"] = 0;
	result["has_loop"] = false;
	result["has_conditional"] = false;
	result["has_call"] = false;
	result["has_return"] = false;
	result["min_statements_required"] = (int)structure_spec.get("min_statements", 1);
	result["required_features_missing"] = Array();
	result["errors"] = Array();
	result["valid"] = false;
	result["quality"] = 0.0;

	if (!result["tree_parsed"]) {
		Array errors = result["errors"];
		errors.append("Syntax error: code could not be parsed into a C++ AST.");
		result["errors"] = errors;
		return result;
	}

	String function_name = structure_spec.get("function_name", String(""));
	if (function_name.is_empty()) {
		Array errors = result["errors"];
		errors.append("Spec is missing 'function_name'.");
		result["errors"] = errors;
		return result;
	}

	TSNode func_def = ast_utils::find_function_declaration(root, function_name, code);
	if (ts_node_is_null(func_def)) {
		Array errors = result["errors"];
		errors.append("Function '" + function_name + "' was not declared in your code.");
		result["errors"] = errors;
		return result;
	}
	result["function_found"] = true;
	result["function_name"] = function_name;

	String return_type_text = ast_utils::get_function_return_type_text(func_def, code);
	result["actual_return_type"] = return_type_text;

	String expected_return = structure_spec.get("expected_return", String(""));
	if (!expected_return.is_empty()) {
		// Substring match: "vector" matches "vector<int>", "int" matches "int", etc.
		bool matches = return_type_text.find(expected_return) != -1;
		result["return_type_match"] = matches;
		if (!matches) {
			Array errors = result["errors"];
			errors.append("Return type mismatch: expected a type containing '" + expected_return + "', got '" + return_type_text + "'.");
			result["errors"] = errors;
			// continue collecting metadata
		}
	} else {
		// No expected_return specified — accept whatever the AST shows
		result["return_type_match"] = !return_type_text.is_empty();
	}

	result["param_count"] = ast_utils::count_function_parameters(func_def);
	result["statement_count"] = ast_utils::count_function_body_statements(func_def);
	result["has_loop"] = ast_utils::function_has_loop(func_def);
	result["has_conditional"] = ast_utils::function_has_conditional(func_def);
	result["has_call"] = ast_utils::function_has_call(func_def);
	result["has_return"] = ast_utils::function_has_return(func_def);

	Array required_features = structure_spec.get("required_features", Array());
	Array missing_features;
	for (int i = 0; i < required_features.size(); i++) {
		String feature = (String)required_features[i];
		if (!_check_required_feature(feature, func_def)) {
			missing_features.append(feature);
		}
	}
	result["required_features_missing"] = missing_features;

	if (missing_features.size() > 0) {
		Array errors = result["errors"];
		String joined = "";
		for (int i = 0; i < missing_features.size(); i++) {
			if (i > 0) {
				joined += ", ";
			}
			joined += String((String)missing_features[i]);
		}
		errors.append("Missing required features: " + joined + ".");
		result["errors"] = errors;
	}

	int min_stmts = (int)structure_spec.get("min_statements", 1);
	int actual_stmts = (int)result["statement_count"];
	if (actual_stmts < min_stmts) {
		Array errors = result["errors"];
		errors.append("Function body is too simple: expected at least " + String::num_int64(min_stmts) +
					 " statements, found " + String::num_int64(actual_stmts) + ".");
		result["errors"] = errors;
	}

	// Compute a 0.0–1.0 quality score based on structural richness
	double quality = 0.0;
	bool return_type_match = (bool)result["return_type_match"];
	if ((bool)result["function_found"]) {
		quality = 0.4; // base for finding the right function
		if (return_type_match) {
			quality += 0.2;
		}
		if ((bool)result["has_return"]) {
			quality += 0.1;
		}
		if ((bool)result["has_loop"]) {
			quality += 0.15;
		}
		if ((bool)result["has_conditional"]) {
			quality += 0.05;
		}
		if ((bool)result["has_call"]) {
			quality += 0.05;
		}
		// reward body complexity, capped
		quality += (actual_stmts >= min_stmts) ? 0.05 : 0.0;
	}
	if (missing_features.size() == 0 && return_type_match && actual_stmts >= min_stmts) {
		result["valid"] = true;
	}
	if (quality > 1.0) {
		quality = 1.0;
	}
	result["quality"] = quality;

	return result;
}

} // namespace validators
} // namespace godot
