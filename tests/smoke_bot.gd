extends SceneTree
## Plays every floor for 10 seconds with scripted input and fails on any engine error.
##   godot4 --headless --fixed-fps 60 --path . -s tests/smoke_bot.gd
## Run without --headless and with `-- --perf` to also fail on frames slower than 16.7 ms.

const ErrorLogger := preload("res://tests/error_logger.gd")
const SECONDS_PER_FLOOR: float = 10.0
const ACTIONS: Array[StringName] = [&"move_forward", &"move_left", &"move_back", &"move_right"]

var _logger: ErrorLogger


func _initialize() -> void:
	_logger = ErrorLogger.new()
	OS.add_logger(_logger)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var perf: bool = "--perf" in OS.get_cmdline_user_args()
	var game: Node = root.get_node(^"Game")
	game.set(&"god_mode", true)
	var floors: PackedStringArray = game.get(&"FLOORS")
	var total: int = 0
	var passed: int = 0

	for floor_name: String in floors:
		if not FileAccess.file_exists("res://levels/%s.txt" % floor_name):
			continue
		total += 1
		var errors_before: int = _logger.count()
		var problems: PackedStringArray = []
		if not game.call(&"load_level", floor_name):
			problems.append("did not load")
		else:
			var slow_frames: int = 0
			var worst_ms: float = 0.0
			var frames: int = int(SECONDS_PER_FLOOR * 60.0)
			for frame: int in frames:
				var player: Node3D = game.get(&"player")
				if player != null and is_instance_valid(player):
					_drive(player, frame)
				await physics_frame
				if perf and frame > 120:
					var ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
					worst_ms = maxf(worst_ms, ms)
					if ms > 16.7:
						slow_frames += 1
			_release_all()
			if perf:
				print("PERF %s worst_frame_ms=%.2f slow_frames=%d enemies=%d" % [
					floor_name, worst_ms, slow_frames, int(game.get(&"alive_enemies"))])
				if slow_frames > 0:
					problems.append("%d frames over 16.7 ms (worst %.2f)" % [slow_frames, worst_ms])
		for i: int in range(errors_before, _logger.count()):
			problems.append("engine error: " + _logger.errors[i])
		if problems.is_empty():
			passed += 1
		for p: String in problems:
			print("FAIL smoke_bot::%s %s" % [floor_name, p])

	game.call(&"unload_level")
	print("TESTS %d/%d" % [passed, total])
	OS.remove_logger(_logger)
	quit(0 if passed == total and total > 0 else 1)


## Wander, spin, punch, grab and throw. Not smart, just busy.
func _drive(player: Node3D, frame: int) -> void:
	var phase: int = (frame / 45) % ACTIONS.size()
	for i: int in ACTIONS.size():
		if i == phase:
			Input.action_press(ACTIONS[i])
		else:
			Input.action_release(ACTIONS[i])
	player.rotate_y(0.035)
	var hands: Node = player.get(&"hands")
	if hands == null:
		return
	if frame % 30 == 0:
		hands.call(&"primary")
	if frame % 50 == 25:
		hands.call(&"secondary")
	if frame % 170 == 0:
		hands.call(&"interact")


func _release_all() -> void:
	for a: StringName in ACTIONS:
		Input.action_release(a)
