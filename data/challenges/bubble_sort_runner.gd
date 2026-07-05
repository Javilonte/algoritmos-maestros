extends RefCounted
class_name BubbleSortRunner

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var input_arr: Array = []
	if test.inputs.size() > 0 and test.inputs[0] is Array:
		input_arr = (test.inputs[0] as Array).duplicate()
	var actual: Array = _bubble_sort(input_arr)
	var expected: Array = test.expected if test.expected is Array else []
	var passed := _arrays_equal(actual, expected)
	var error := "" if passed else "expected %s, got %s" % [str(expected), str(actual)]
	return { "passed": passed, "actual": actual, "error": error }

static func _bubble_sort(arr: Array) -> Array:
	var n := arr.size()
	for i in n:
		for j in range(0, n - i - 1):
			if arr[j] > arr[j + 1]:
				var tmp = arr[j]
				arr[j] = arr[j + 1]
				arr[j + 1] = tmp
	return arr

static func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true
