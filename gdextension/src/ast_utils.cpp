#include "ast_utils.h"

#include <cstring>

namespace godot {
namespace ast_utils {

String node_text(TSNode node, const String &source) {
	uint32_t start = ts_node_start_byte(node);
	uint32_t end = ts_node_end_byte(node);
	return source.substr(start, end - start);
}

bool node_type_is(TSNode node, const char *type) {
	return strcmp(ts_node_type(node), type) == 0;
}

TSNode find_child(TSNode node, const char *type) {
	uint32_t count = ts_node_named_child_count(node);
	for (uint32_t i = 0; i < count; i++) {
		TSNode child = ts_node_named_child(node, i);
		if (node_type_is(child, type)) {
			return child;
		}
	}
	return {};
}

bool has_descendant_of_type(TSNode node, const char *type) {
	TSTreeCursor cursor = ts_tree_cursor_new(node);
	bool found = false;
	if (ts_tree_cursor_goto_first_child(&cursor)) {
		do {
			TSNode current = ts_tree_cursor_current_node(&cursor);
			if (node_type_is(current, type)) {
				found = true;
				break;
			}
			if (has_descendant_of_type(current, type)) {
				found = true;
				break;
			}
		} while (ts_tree_cursor_goto_next_sibling(&cursor));
	}
	ts_tree_cursor_delete(&cursor);
	return found;
}

bool returns_literal_zero(TSNode node, const String &code) {
	TSTreeCursor cursor = ts_tree_cursor_new(node);
	bool result = false;
	if (ts_tree_cursor_goto_first_child(&cursor)) {
		do {
			TSNode child = ts_tree_cursor_current_node(&cursor);
			if (node_type_is(child, "return_statement")) {
				uint32_t child_count = ts_node_named_child_count(child);
				for (uint32_t i = 0; i < child_count; i++) {
					TSNode gc = ts_node_named_child(child, i);
					if (node_type_is(gc, "number_literal") && node_text(gc, code) == "0") {
						result = true;
						break;
					}
				}
				break;
			}
			if (returns_literal_zero(child, code)) {
				result = true;
				break;
			}
		} while (ts_tree_cursor_goto_next_sibling(&cursor));
	}
	ts_tree_cursor_delete(&cursor);
	return result;
}

// === Phase 2 helpers ===

static bool _scan_function_name(TSNode node, const String &needle, const String &source) {
	TSTreeCursor cursor = ts_tree_cursor_new(node);
	bool found = false;
	if (ts_tree_cursor_goto_first_child(&cursor)) {
		do {
			TSNode current = ts_tree_cursor_current_node(&cursor);
			if (node_type_is(current, "function_definition")) {
				TSNode declarator = find_child(current, "function_declarator");
				if (!ts_node_is_null(declarator)) {
					TSNode id_node = find_child(declarator, "identifier");
					if (!ts_node_is_null(id_node) && node_text(id_node, source) == needle) {
						found = true;
						break;
					}
				}
			}
			if (!found && _scan_function_name(current, needle, source)) {
				found = true;
				break;
			}
		} while (ts_tree_cursor_goto_next_sibling(&cursor));
	}
	ts_tree_cursor_delete(&cursor);
	return found;
}

TSNode find_function_declaration(TSNode root, const String &name, const String &source) {
	(void)source; // silence unused warning when helpers short-circuit
	if (name.is_empty()) {
		return {};
	}
	uint32_t count = ts_node_named_child_count(root);
	for (uint32_t i = 0; i < count; i++) {
		TSNode node = ts_node_named_child(root, i);
		if (node_type_is(node, "function_definition")) {
			TSNode declarator = find_child(node, "function_declarator");
			if (!ts_node_is_null(declarator)) {
				TSNode id_node = find_child(declarator, "identifier");
				if (!ts_node_is_null(id_node) && node_text(id_node, source) == name) {
					return node;
				}
			}
		}
		TSNode found = find_function_declaration(node, name, source);
		if (!ts_node_is_null(found)) {
			return found;
		}
	}
	return {};
}

String get_function_return_type_text(TSNode func_def, const String &source) {
	if (ts_node_is_null(func_def) || !node_type_is(func_def, "function_definition")) {
		return "";
	}
	// return type appears as one of the first named children of the function_definition,
	// before the function_declarator. Common types: primitive_type, type_identifier,
	// template_type, qualified_identifier, placeholder_type.
	static const char *type_kinds[] = {
		"primitive_type", "type_identifier", "template_type",
		"qualified_identifier", "placeholder_type", "auto"
	};
	for (const char *kind : type_kinds) {
		TSNode t = find_child(func_def, kind);
		if (!ts_node_is_null(t)) {
			return node_text(t, source);
		}
	}
	// Also accept "struct_specifier" / "class_specifier" for completeness.
	for (const char *kind2 : { "struct_specifier", "class_specifier", "enum_specifier" }) {
		TSNode t = find_child(func_def, kind2);
		if (!ts_node_is_null(t)) {
			return node_text(t, source);
		}
	}
	return "";
}

static int _count_statement_descendants(TSNode node) {
	int count = 0;
	TSTreeCursor cursor = ts_tree_cursor_new(node);
	if (ts_tree_cursor_goto_first_child(&cursor)) {
		do {
			TSNode current = ts_tree_cursor_current_node(&cursor);
			const char *type = ts_node_type(current);
			if (strcmp(type, "if_statement") == 0 ||
				strcmp(type, "for_statement") == 0 ||
				strcmp(type, "while_statement") == 0 ||
				strcmp(type, "do_statement") == 0 ||
				strcmp(type, "range_for_statement") == 0 ||
				strcmp(type, "return_statement") == 0 ||
				strcmp(type, "expression_statement") == 0 ||
				strcmp(type, "declaration") == 0 ||
				strcmp(type, "compound_statement") == 0) {
				count += 1 + _count_statement_descendants(current);
			}
		} while (ts_tree_cursor_goto_next_sibling(&cursor));
	}
	ts_tree_cursor_delete(&cursor);
	return count;
}

int count_function_body_statements(TSNode func_def) {
	if (ts_node_is_null(func_def)) {
		return 0;
	}
	TSNode body = find_child(func_def, "compound_statement");
	if (ts_node_is_null(body)) {
		return 0;
	}
	return _count_statement_descendants(body);
}

int count_function_parameters(TSNode func_def) {
	if (ts_node_is_null(func_def)) {
		return 0;
	}
	TSNode declarator = find_child(func_def, "function_declarator");
	if (ts_node_is_null(declarator)) {
		return 0;
	}
	TSNode params = find_child(declarator, "parameter_list");
	if (ts_node_is_null(params)) {
		return 0;
	}
	uint32_t count = ts_node_named_child_count(params);
	int n = 0;
	for (uint32_t i = 0; i < count; i++) {
		TSNode c = ts_node_named_child(params, i);
		const char *type = ts_node_type(c);
		// Skip punctuation-like children and the "void" specifier
		if (strcmp(type, "parameter_declaration") == 0) {
			n += 1;
		}
	}
	return n;
}

bool function_has_loop(TSNode func_def) {
	if (ts_node_is_null(func_def)) {
		return false;
	}
	TSNode body = find_child(func_def, "compound_statement");
	if (ts_node_is_null(body)) {
		return false;
	}
	static const char *loop_kinds[] = {
		"for_statement", "for_range_loop",
		"while_statement", "do_statement",
		"range_for_statement"
	};
	for (const char *kind : loop_kinds) {
		if (has_descendant_of_type(body, kind)) {
			return true;
		}
	}
	return false;
}

bool function_has_conditional(TSNode func_def) {
	if (ts_node_is_null(func_def)) {
		return false;
	}
	TSNode body = find_child(func_def, "compound_statement");
	if (ts_node_is_null(body)) {
		return false;
	}
	return has_descendant_of_type(body, "if_statement");
}

bool function_has_call(TSNode func_def) {
	if (ts_node_is_null(func_def)) {
		return false;
	}
	TSNode body = find_child(func_def, "compound_statement");
	if (ts_node_is_null(body)) {
		return false;
	}
	return has_descendant_of_type(body, "call_expression");
}

bool function_has_return(TSNode func_def) {
	if (ts_node_is_null(func_def)) {
		return false;
	}
	TSNode body = find_child(func_def, "compound_statement");
	if (ts_node_is_null(body)) {
		return false;
	}
	return has_descendant_of_type(body, "return_statement");
}

} // namespace ast_utils
} // namespace godot
