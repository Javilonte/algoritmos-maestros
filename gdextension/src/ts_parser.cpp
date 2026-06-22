#include "ts_parser.h"

#include <tree_sitter/api.h>

#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

extern "C" const TSLanguage *tree_sitter_cpp(void);

namespace godot {

TreeSitterParser::TreeSitterParser() {
	_parser = ts_parser_new();
	if (_parser) {
		ts_parser_set_language(_parser, tree_sitter_cpp());
	}
	_tree = nullptr;
}

TreeSitterParser::~TreeSitterParser() {
	_clear_tree();
	ts_parser_delete(_parser);
}

void TreeSitterParser::_clear_tree() {
	if (_tree) {
		ts_tree_delete(_tree);
		_tree = nullptr;
	}
}

void TreeSitterParser::_bind_methods() {
	ClassDB::bind_method(D_METHOD("validate", "code", "challenge_id"), &TreeSitterParser::validate);
}

Dictionary TreeSitterParser::validate(const String &code, const String &challenge_id) {
	_clear_tree();

	CharString cs = code.utf8();
	_tree = ts_parser_parse_string(_parser, nullptr, cs.get_data(), (uint32_t)cs.length());

	if (!_tree) {
		Dictionary result;
		result["success"] = false;
		result["message"] = "Internal error: parser failed to produce a syntax tree.";
		return result;
	}

	if (challenge_id == "main_exit_check") {
		return _validate_main_exit(code);
	}

	Dictionary result;
	result["success"] = false;
	result["message"] = "Unknown challenge '" + challenge_id + "'.";
	return result;
}

static String _node_text(TSNode node, const String &source) {
	uint32_t start = ts_node_start_byte(node);
	uint32_t end = ts_node_end_byte(node);
	return source.substr(start, end - start);
}

static bool _node_type_is(TSNode node, const char *type) {
	return strcmp(ts_node_type(node), type) == 0;
}

static TSNode _find_child(TSNode node, const char *type) {
	uint32_t count = ts_node_named_child_count(node);
	for (uint32_t i = 0; i < count; i++) {
		TSNode child = ts_node_named_child(node, i);
		if (_node_type_is(child, type)) {
			return child;
		}
	}
	return {};
}

static bool _has_descendant_of_type(TSNode node, const char *type) {
	TSTreeCursor cursor = ts_tree_cursor_new(node);
	bool found = false;
	if (ts_tree_cursor_goto_first_child(&cursor)) {
		do {
			TSNode current = ts_tree_cursor_current_node(&cursor);
			if (_node_type_is(current, type)) {
				found = true;
				break;
			}
			if (_has_descendant_of_type(current, type)) {
				found = true;
				break;
			}
		} while (ts_tree_cursor_goto_next_sibling(&cursor));
	}
	ts_tree_cursor_delete(&cursor);
	return found;
}

static bool _returns_literal_zero(TSNode node, const String &code) {
	TSTreeCursor cursor = ts_tree_cursor_new(node);
	bool result = false;
	if (ts_tree_cursor_goto_first_child(&cursor)) {
		do {
			TSNode child = ts_tree_cursor_current_node(&cursor);
			if (_node_type_is(child, "return_statement")) {
				uint32_t child_count = ts_node_named_child_count(child);
				for (uint32_t i = 0; i < child_count; i++) {
					TSNode gc = ts_node_named_child(child, i);
					if (_node_type_is(gc, "number_literal") && _node_text(gc, code) == "0") {
						result = true;
						break;
					}
				}
				break;
			}
			if (_returns_literal_zero(child, code)) {
				result = true;
				break;
			}
		} while (ts_tree_cursor_goto_next_sibling(&cursor));
	}
	ts_tree_cursor_delete(&cursor);
	return result;
}

Dictionary TreeSitterParser::_validate_main_exit(const String &code) {
	Dictionary result;
	TSNode root = ts_tree_root_node(_tree);

	if (ts_node_has_error(root)) {
		result["success"] = false;
		result["message"] = "Syntax error: your code contains invalid C++.";
		return result;
	}

	TSNode func_def = _find_child(root, "function_definition");
	if (ts_node_is_null(func_def)) {
		result["success"] = false;
		result["message"] = "No function definition found. Expected: 'int main() { ... }'.";
		return result;
	}

	TSNode ret_type = _find_child(func_def, "primitive_type");
	if (ts_node_is_null(ret_type) || _node_text(ret_type, code) != "int") {
		result["success"] = false;
		result["message"] = "Function must return 'int'.";
		return result;
	}

	TSNode declarator = _find_child(func_def, "function_declarator");
	if (!ts_node_is_null(declarator)) {
		TSNode id_node = _find_child(declarator, "identifier");
		if (!ts_node_is_null(id_node) && _node_text(id_node, code) != "main") {
			result["success"] = false;
			result["message"] = "Expected function named 'main', got '" + _node_text(id_node, code) + "'.";
			return result;
		}
	}

	if (!_returns_literal_zero(func_def, code)) {
		Dictionary msg_result;
		if (_has_descendant_of_type(func_def, "return_statement")) {
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

}
