#include "ts_parser.h"

#include <tree_sitter/api.h>

#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "validators.h"

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

	return validators::run(challenge_id, _tree, code);
}

}
