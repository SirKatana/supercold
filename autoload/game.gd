extends Node
## Floor flow and run state: loading floors, spawning dudes and waves, tracking
## kills, restarting on death, moving on when a floor is clear.

signal state_changed(state: State)
signal floor_loaded(data: LevelData)
signal floor_cleared
signal enemy_killed(remaining: int)
signal run_finished

enum State { TITLE, PLAYING, DEAD, CLEARED, ENDING }

const T: Tuning = preload("res://data/tuning.tres")
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const DUDE_SCENE: PackedScene = preload("res://enemies/pink_dude.tscn")
const FLOORS: PackedStringArray = ["f1_lobby", "f2_offices", "f3_servers", "f4_labs", "f5_executive", "roof"]

var state: State = State.TITLE
var level_root: Node3D
var level: Node3D
var data: LevelData
var player: Player
var floor_index: int = 0
var level_name: String = ""
var kills: int = 0
var alive_enemies: int = 0
## Debug and test aid: the player cannot die.
var god_mode: bool = false

var _pending_waves: Array[Dictionary] = []
var _load_serial: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart") and (state == State.PLAYING or state == State.DEAD):
		restart_floor.call_deferred()


func _set_state(next: State) -> void:
	state = next
	state_changed.emit(next)


# ---------------------------------------------------------------- run flow

func start_run(from_floor: int = 0) -> void:
	load_floor(from_floor)


func load_floor(index: int) -> bool:
	floor_index = clampi(index, 0, FLOORS.size() - 1)
	return load_level(FLOORS[floor_index])


func restart_floor() -> void:
	if level_name != "":
		load_level(level_name)


func next_floor() -> void:
	var index: int = FLOORS.find(level_name)
	if index < 0 or index >= FLOORS.size() - 1:
		_set_state(State.ENDING)
		run_finished.emit()
		return
	load_floor(index + 1)


# ---------------------------------------------------------------- loading

func _ensure_root() -> void:
	if level_root == null or not is_instance_valid(level_root):
		level_root = Node3D.new()
		level_root.name = "LevelRoot"
		get_tree().root.add_child(level_root)


## Where loose world objects (bullets, dropped items, shards) should live.
func entities_root(fallback: Node) -> Node:
	if level != null and is_instance_valid(level):
		return level.get_node(^"Entities")
	# No level (unit tests): stay beside the caller so nothing leaks into the tree root.
	var parent: Node = fallback.get_parent()
	return parent if parent != null else fallback.get_tree().root


func unload_level() -> void:
	_load_serial += 1
	if level != null and is_instance_valid(level):
		level.free()
	level = null
	player = null
	alive_enemies = 0
	_pending_waves.clear()


func load_level(name_of_level: String) -> bool:
	_ensure_root()
	unload_level()
	data = LevelParser.load_level(name_of_level)
	if not data.errors.is_empty():
		for e: String in data.errors:
			push_error("level %s: %s" % [name_of_level, e])
		return false
	level_name = name_of_level
	kills = 0
	level = LevelBuilder.build(data)
	level_root.add_child(level)
	LevelBuilder.bake_navigation(level, data)

	player = PLAYER_SCENE.instantiate()
	level.add_child(player)
	player.global_position = data.cell_center(data.player_start, 0.05)
	var centre := Vector3(data.width * data.cell_size * 0.5, 0.05, data.height * data.cell_size * 0.5)
	if centre.distance_to(player.global_position) > 0.5:
		player.look_at(Vector3(centre.x, player.global_position.y, centre.z))
	player.died.connect(_on_player_died)

	for spawn: Dictionary in data.spawns:
		spawn_dude(data.cell_center(spawn["cell"], 0.05), spawn["armed"])
	if data.boss_cell.x >= 0:
		spawn_boss(data.cell_center(data.boss_cell, 0.05))
	for wave: Dictionary in data.waves:
		_pending_waves.append(wave.duplicate())

	TimeManager.reset()
	_set_state(State.PLAYING)
	floor_loaded.emit(data)
	return true


# ---------------------------------------------------------------- enemies

func spawn_dude(at: Vector3, armed: bool) -> PinkDude:
	var dude: PinkDude = DUDE_SCENE.instantiate()
	dude.armed_at_spawn = armed
	_register(dude, at)
	return dude


func spawn_boss(at: Vector3) -> PinkDude:
	var boss: PinkDude = DUDE_SCENE.instantiate()
	boss.set_script(load("res://enemies/director.gd"))
	_register(boss, at)
	return boss


func _register(dude: PinkDude, at: Vector3) -> void:
	entities_root(self).add_child(dude)
	dude.global_position = at
	if player != null:
		var look: Vector3 = player.global_position
		if dude.flat_distance_to(look) > 0.5:
			dude.look_at(Vector3(look.x, at.y, look.z))
	dude.died.connect(_on_dude_died)
	alive_enemies += 1


## Spawns `count` dudes spread over the level's wave points, already alerted.
func spawn_wave(count: int, armed: int) -> void:
	if data == null or data.wave_points.is_empty():
		return
	for i: int in count:
		var cell: Vector2i = data.wave_points[i % data.wave_points.size()]
		var jitter := Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		var dude: PinkDude = spawn_dude(data.cell_center(cell, 0.05) + jitter, i < armed)
		dude.alerted = true


func trigger_fired() -> void:
	for wave: Dictionary in _pending_waves.duplicate():
		if wave["on_trigger"]:
			_pending_waves.erase(wave)
			spawn_wave(wave["count"], wave["armed"])
			return


func emit_noise(at: Vector3, radius: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude != null and dude.alive and dude.global_position.distance_to(at) <= radius:
			dude.hear(at)


func is_floor_clear() -> bool:
	return alive_enemies <= 0 and _pending_waves.is_empty()


func _on_dude_died(_dude: PinkDude) -> void:
	kills += 1
	alive_enemies -= 1
	enemy_killed.emit(alive_enemies)
	for wave: Dictionary in _pending_waves.duplicate():
		if not wave["on_trigger"] and wave["after_kills"] >= 0 and kills >= wave["after_kills"]:
			_pending_waves.erase(wave)
			spawn_wave(wave["count"], wave["armed"])
	# A trigger wave the player never walked into must not soft-lock the floor.
	if alive_enemies <= 0 and not _pending_waves.is_empty():
		var wave: Dictionary = _pending_waves.pop_front()
		spawn_wave(wave["count"], wave["armed"])
	if is_floor_clear() and state == State.PLAYING:
		_set_state(State.CLEARED)
		floor_cleared.emit()


func _on_player_died() -> void:
	if state != State.PLAYING and state != State.CLEARED:
		return
	_set_state(State.DEAD)
	Sfx.play(&"death")
	var serial: int = _load_serial
	await get_tree().create_timer(T.death_restart_delay, true, false, true).timeout
	if serial == _load_serial and state == State.DEAD:
		restart_floor()
