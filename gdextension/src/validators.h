#ifndef VALIDATORS_H
#define VALIDATORS_H

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

typedef struct TSTree TSTree;

namespace godot {
namespace validators {

// Looks up challenge_id in the validator registry and runs the matching
// check against the parsed tree. Returns {"success": false, "message":
// "Unknown challenge '<id>'."} if no validator is registered for the id.
Dictionary run(const String &challenge_id, TSTree *tree, const String &code);

}
}

#endif
