#ifndef TS_PARSER_H
#define TS_PARSER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

typedef struct TSParser TSParser;
typedef struct TSTree TSTree;
typedef struct TSLanguage TSLanguage;

namespace godot {

class TreeSitterParser : public RefCounted {
	GDCLASS(TreeSitterParser, RefCounted)

	TSParser *_parser;
	TSTree *_tree;

	void _clear_tree();
	Dictionary _validate_main_exit(const String &code);

protected:
	static void _bind_methods();

public:
	TreeSitterParser();
	~TreeSitterParser();

	Dictionary validate(const String &code, const String &challenge_id);
};

}

#endif
