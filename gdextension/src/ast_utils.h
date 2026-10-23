#ifndef AST_UTILS_H
#define AST_UTILS_H

#include <tree_sitter/api.h>

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {
namespace ast_utils {

String node_text(TSNode node, const String &source);
bool node_type_is(TSNode node, const char *type);
TSNode find_child(TSNode node, const char *type);
bool has_descendant_of_type(TSNode node, const char *type);
bool returns_literal_zero(TSNode node, const String &code);

// === AST inspector helpers (Phase 2 validator pipeline) ===

// Find a function_definition node by name anywhere in the tree.
TSNode find_function_declaration(TSNode root, const String &name, const String &source);

// Get the return type token text from a function_definition ("int", "void", "vector", ...).
// Returns the raw token text from the first type-specifier child, or "" if not found.
String get_function_return_type_text(TSNode func_def, const String &source);

// Count "real" statements inside a function body (excludes braces).
int count_function_body_statements(TSNode func_def);

// Count parameter declarations in a function declarator.
int count_function_parameters(TSNode func_def);

// True if the function body contains a statement that triggers a loop
// (for_statement, while_statement, do_statement, range_for_statement).
bool function_has_loop(TSNode func_def);

// True if the function body contains at least one if_statement / else_clause.
bool function_has_conditional(TSNode func_def);

// True if the body contains a call_expression (heuristic for "uses function call").
bool function_has_call(TSNode func_def);

// True if the body contains a return_statement (any return at any nesting).
bool function_has_return(TSNode func_def);

} // namespace ast_utils
} // namespace godot

#endif
