extends SceneTree
## Plays every floor for 10 seconds with scripted input and fails on any engine error.
##   godot4 --headless --fixed-fps 60 --path . -s tests/smoke_bot.gd
## Run without --headless and with `-- --perf` to also fail on frames slower than 16.7 ms.

const ErrorLogger := preload("res://tests/error_logger.gd")
const SECONDS_PER_FLOOR: float = 10.0
const ACTIONS: Array[StringName] = [&"move_forward", &"move_left", &"move_back", &"move_right"]

var _logger: ErrorLogger
var _recording: bool = false
var _frame_ms: PackedFloat32Array = []
var _last_usec: int = 0
var _bot_frame: int = 0
var _spikes: PackedStringArray = []


func _initialize() -> void:
	_logger = ErrorLogger.new()
	OS.add_logger(_logger)
	process_frame.connect(_on_frame)
	_run.call_deferred()


## Real interval between rendered frames. The Performance TIME_* monitors are
## per-second maxima, so they cannot answer "was any frame slow".
func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _recording and _last_usec > 0:
		_frame_ms.append((now - _last_usec) / 1000.0)
		if (now - _last_usec) / 1000.0 > 16.7:
			_spikes.append("%d:%.0fms" % [_bot_frame, (now - _last_usec) / 1000.0])
	_last_usec = now


func _run() -> void:
	await process_frame
	var perf: bool = "--perf" in OS.get_cmdline_user_args()
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--floor="):
			only = arg.trim_prefix("--floor=")
	var game: Node = root.get_node(^"Game")
	game.set(&"god_mode", true)
	game.set(&"fast_elevators", true)
	var floors: PackedStringArray = game.get(&"FLOORS")
	var total: int = 0
	var passed: int = 0

	for floor_name: String in floors:
		if not FileAccess.file_exists("res://levels/%s.txt" % floor_name):
			continue
		if only != "" and floor_name != only:
			continue
		total += 1
		var errors_before: int = _logger.count()
		var problems: PackedStringArray = []
		if not game.call(&"load_level", floor_name):
			problems.append("did not load")
		else:
			var slow_frames: int = 0
			var worst_ms: float = 0.0
			var samples: PackedFloat32Array = []
			var frames: int = int(SECONDS_PER_FLOOR * 60.0)
			for frame: int in frames:
				var player: Node3D = game.get(&"player")
				if player != null and is_instance_valid(player):
					_drive(player, frame)
				if perf and not ("--no-volley" in OS.get_cmdline_user_args()) and frame % 150 == 130 and player != null and is_instance_valid(player):
					# Loaded at runtime: a `-s` entry script compiles before autoloads exist,
					# so it must not name any class that refers to Game or TimeManager.
					var pool_script: GDScript = load("res://weapons/bullet_pool.gd")
					var pool: Node = pool_script.call(&"for_node", player)
					for b: int in 40:
						var dir := Vector3(sin(b * 0.157), 0.35, cos(b * 0.157)).normalized()
						pool.call(&"fire", player.global_position + Vector3(0, 1.5, 0), dir, player)
				await physics_frame
				_recording = perf and frame > 300
				_bot_frame = frame
			_release_all()
			_recording = false
			samples = _frame_ms.duplicate()
			_frame_ms.clear()
			for ms: float in samples:
				worst_ms = maxf(worst_ms, ms)
				if ms > 16.7:
					slow_frames += 1
			if perf:
				print("SPIKES ", ", ".join(_spikes))
				_spikes.clear()
				samples.sort()
				var median: float = samples[samples.size() / 2] if samples.size() > 0 else 0.0
				var p95: float = samples[int(samples.size() * 0.95)] if samples.size() > 0 else 0.0
				print("PERF %s median_ms=%.2f p95_ms=%.2f worst_ms=%.2f slow_frames=%d frames=%d fps=%d enemies=%d" % [
					floor_name, median, p95, worst_ms, slow_frames, samples.size(),
					int(Performance.get_monitor(Performance.TIME_FPS)), int(game.get(&"alive_enemies"))])
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
