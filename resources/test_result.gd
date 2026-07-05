class_name TestResult extends RefCounted

var challenge_id: String = ""
var passed: int = 0
var total: int = 0
var compile_time_ms: int = 0
var execute_time_ms: int = 0
var errors: Array[String] = []
var failed_test_names: Array[String] = []
var success: bool = false
var ast_valid: bool = false
var ast_quality: float = 0.0
var ast_summary: String = ""

func pass_ratio() -> float:
	if total <= 0:
		return 0.0
	return float(passed) / float(total)
