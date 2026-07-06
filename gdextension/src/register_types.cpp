#include "register_types.h"
#include "ts_parser.h"
#include "combat_algorithm_evaluator.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_algorithm_validator_types(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SERVERS) {
		GDREGISTER_CLASS(TreeSitterParser);
		GDREGISTER_CLASS(CombatAlgorithmEvaluator);
	}
}

void uninitialize_algorithm_validator_types(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SERVERS) {
	}
}

extern "C" {

GDExtensionBool GDE_EXPORT algorithm_validator_init(
	GDExtensionInterfaceGetProcAddress p_get_proc_address,
	GDExtensionClassLibraryPtr p_library,
	GDExtensionInitialization *r_initialization
) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_algorithm_validator_types);
	init_obj.register_terminator(uninitialize_algorithm_validator_types);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SERVERS);
	return init_obj.init();
}

}
