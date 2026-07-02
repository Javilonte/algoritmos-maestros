#ifndef AST_UTILS_H
#define AST_UTILS_H

#include <tree_sitter/api.h>

#include <godot_cpp/variant/string.hpp>

namespace godot {
namespace ast_utils {

String node_text(TSNode node, const String &source);
bool node_type_is(TSNode node, const char *type);
TSNode find_child(TSNode node, const char *type);
bool has_descendant_of_type(TSNode node, const char *type);
bool returns_literal_zero(TSNode node, const String &code);

}
}

#endif
