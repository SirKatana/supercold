extends Node
## Base class for test files. Test methods start with `test_` and may await.

const T: Tuning = preload("res://data/tuning.tres")

var failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (got %s, want %s)" % [message, str(actual), str(expected)])


func check_near(actual: float, expected: float, epsilon: float, message: String) -> void:
	if absf(actual - expected) > epsilon:
		failures.append("%s (got %.4f, want %.4f)" % [message, actual, expected])


func wait_physics(frames: int = 2) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func wait_frames(frames: int = 1) -> void:
	for i: int in frames:
		await get_tree().process_frame
