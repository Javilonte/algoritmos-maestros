extends SceneTree

## Verify both GDExtension classes are loaded with their methods bound.

func _init() -> void:
	print("[sanity] _init entered")
	call_deferred("_run")


func _run() -> void:
	print("[sanity] _run started")
	print("========== GDExtension sanity test ==========")

	# TreeSitterParser
	if ClassDB.class_exists("TreeSitterParser"):
		print("[sanity] PASS: TreeSitterParser registered")
		var methods := ClassDB.class_get_method_list("TreeSitterParser", true)
		var has_validate := false
		var has_validate_structure := false
		for m in methods:
			if m.name == "validate":
				has_validate = true
			elif m.name == "validate_structure":
				has_validate_structure = true
		if has_validate:
			print("[sanity] PASS: TreeSitterParser.validate() bound")
		if has_validate_structure:
			print("[sanity] PASS: TreeSitterParser.validate_structure() bound")
			# Functional test of validate_structure
			var tsp: Object = ClassDB.instantiate("TreeSitterParser")
			if tsp != null:
				var spec := {
					"function_name": "main",
					"expected_return": "int",
					"min_statements": 1,
					"required_features": ["return"],
				}
				var vs_result: Dictionary = tsp.validate_structure(
					"int main() { for (int i=0;i<10;i++) { sum += i; } return sum; }",
					spec
				)
				print("[sanity] validate_structure -> valid=%s function_found=%s errors=%s" % [
					vs_result.get("valid", "?"),
					vs_result.get("function_found", "?"),
					vs_result.get("errors", "?"),
				])
			else:
				print("[sanity] FAIL: could not instantiate TreeSitterParser")
		else:
			print("[sanity] FAIL: TreeSitterParser.validate_structure() NOT bound")
	else:
		print("[sanity] FAIL: TreeSitterParser NOT registered")

	# CombatAlgorithmEvaluator
	if ClassDB.class_exists("CombatAlgorithmEvaluator"):
		print("[sanity] PASS: CombatAlgorithmEvaluator registered")
		var methods2 := ClassDB.class_get_method_list("CombatAlgorithmEvaluator", true)
		var has_evaluate := false
		for m in methods2:
			if m.name == "evaluate":
				has_evaluate = true
		if has_evaluate:
			print("[sanity] PASS: CombatAlgorithmEvaluator.evaluate() bound")
		else:
			print("[sanity] FAIL: CombatAlgorithmEvaluator.evaluate() NOT bound")

		# Functional test
		print("[sanity] Instantiating CombatAlgorithmEvaluator...")
		var obj: Object = ClassDB.instantiate("CombatAlgorithmEvaluator")
		if obj != null:
			print("[sanity] PASS: instantiation succeeded")
			var r1: Dictionary = obj.evaluate("int main() { for (int i=0;i<10;i++) { sum += i; } return sum; }", "linear_search")
			print("[sanity] O(n) input -> success=%s damage=%d tier=%s complexity=%s fc=%d ld=%d ms=%d" % [
				r1.get("success", false),
				int(r1.get("damage", 0)),
				r1.get("tier", "?"),
				r1.get("complexity", "?"),
				int(r1.get("function_count", -1)),
				int(r1.get("loop_depth", -1)),
				int(r1.get("evaluation_ms", -1)),
			])
			var r2: Dictionary = obj.evaluate("int main() { for (int i=0;i<n;i++) { for (int j=0;j<n;j++) { sum++; } } return sum; }", "bubble_sort")
			print("[sanity] O(n^2) input -> success=%s damage=%d tier=%s complexity=%s fc=%d ld=%d" % [
				r2.get("success", false),
				int(r2.get("damage", 0)),
				r2.get("tier", "?"),
				r2.get("complexity", "?"),
				int(r2.get("function_count", -1)),
				int(r2.get("loop_depth", -1)),
			])
			var r3: Dictionary = obj.evaluate("", "main_exit_check")
			print("[sanity] empty -> success=%s error=%s" % [r3.get("success", false), r3.get("error_message", "?")])
			var r4: Dictionary = obj.evaluate("int main() { if (true) { return 0;", "main_exit_check")
			print("[sanity] unbalanced -> success=%s error_line=%d" % [r4.get("success", false), int(r4.get("error_line", -1))])
		else:
			print("[sanity] FAIL: instantiation returned null")
	else:
		print("[sanity] FAIL: CombatAlgorithmEvaluator NOT registered")

	print("===============================================")
	print("[sanity] quitting")
	quit(0)


func _exit_tree() -> void:
	print("[sanity] _exit_tree")