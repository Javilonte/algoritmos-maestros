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

}

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

}
}
