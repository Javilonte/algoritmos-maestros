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

}
}
