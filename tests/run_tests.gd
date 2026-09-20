extends SceneTree
## Headless test runner.
##   godot4 --headless --path . -s tests/run_tests.gd [-- --only=test_time]
## Output contract: `FAIL <file>::<test> <message>` per failure, then
## `TESTS <passed>/<total>`. Exit code 1 on any failure or engine error.

const ErrorLogger := preload("res://tests/error_logger.gd")

var _logger: ErrorLogger


func _initialize() -> void:
	_logger = ErrorLogger.new()
	OS.add_logger(_logger)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node(^"Game").set(&"fast_elevators", true)
	root.get_node(^"AdService").set(&"auto_result", 1)
	# No talking computer during automated runs. Loaded at runtime: see the note on -s scripts.
	(load("res://allies/helper_voice.gd") as GDScript).set(&"tts_enabled", false)
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")

	var files: PackedStringArray = []
	for f: String in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			if only == "" or f.get_basename() == only:
				files.append(f)
	files.sort()

	var total: int = 0
	var passed: int = 0
	for f: String in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null:
			print("FAIL %s::load could not load script" % f)
			total += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var case: Node = script.new()
			root.add_child(case)
			var errors_before: int = _logger.count()
			await case.call(&"before_each")
			await case.call(method_name)
			await case.call(&"after_each")
			var failures: PackedStringArray = case.get(&"failures")
			for i: int in range(errors_before, _logger.count()):
				failures.append("engine error: " + _logger.errors[i])
			if failures.is_empty():
				passed += 1
			for message: String in failures:
				print("FAIL %s::%s %s" % [f, method_name, message])
			case.queue_free()
			await process_frame

	print("TESTS %d/%d" % [passed, total])
	OS.remove_logger(_logger)
	quit(0 if passed == total and total > 0 else 1)
