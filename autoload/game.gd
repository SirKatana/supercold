extends Node
## Floor flow and run state: loading floors, spawning dudes and waves, tracking
## kills, restarting on death, moving on when a floor is clear.

signal state_changed(state: State)
signal floor_loaded(data: LevelData)
signal floor_cleared
signal enemy_killed(remaining: int)
signal run_finished
## The player stepped out of the arrival elevator. The HUD announces the level on this.
signal floor_announced(label: String, intro: String)
signal helper_changed(active: bool)
signal super_gun_granted

enum State { TITLE, PLAYING, DEAD, CLEARED, ENDING }

const T: Tuning = preload("res://data/tuning.tres")
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const DUDE_SCENE: PackedScene = preload("res://enemies/pink_dude.tscn")
const FLOORS: PackedStringArray = [
	"f1_lobby", "f2_offices", "f3_servers", "f4_labs", "f5_executive",
	"f6_cafeteria", "f7_garage", "f8_archive", "f9_pool", "f10_vault",
	"f11_sewers", "f12_kitchen", "f13_coldstore", "f14_glassworks", "f15_restrooms",
	"f16_armoury", "f17_greenhouse", "f18_beanworks", "f19_tradingfloor", "f20_generators",
	"f21_lockdown", "f22_cryolab", "f23_mirrors", "f24_strongrooms", "f25_skygarden",
	"f26_morgue", "f27_furnace", "f28_waterworks", "f29_penthouse", "roof",
]

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
var deaths: int = 0
## Deaths on the current floor. Three of them bring out the helper capsule.
var deaths_this_floor: int = 0
## Real seconds of hired help left. Survives a death and restart, ends when the floor is clear.
var helper_time_left: float = 0.0
var helper: Helper = null
## Won from the Brute. From then on the player starts every floor holding it.
var has_super_gun: bool = false
## Furthest floor reached, for Continue on the title screen.
var best_floor: int = 0

const PROGRESS_PATH: String = "user://progress.cfg"
## Tests and the smoke bot: doors are already open and rides take a blink.
var fast_elevators: bool = false
## Set while reloading after a death, so the retry starts almost at once.
var quick_arrival: bool = false
var run_seconds: float = 0.0

var _pending_waves: Array[Dictionary] = []
var _load_serial: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart") and (state == State.PLAYING or state == State.DEAD):
		restart_floor.call_deferred()


func _set_state(next: State) -> void:
	state = next
	state_changed.emit(next)


# ---------------------------------------------------------------- run flow

func start_run(from_floor: int = 0) -> void:
	deaths = 0
	deaths_this_floor = 0
	helper_time_left = 0.0
	level_name = ""
	run_seconds = 0.0
	load_floor(from_floor)


## Tests: forget the run so one test's deaths and helper do not leak into the next.
func start_run_state_for_tests() -> void:
	has_super_gun = false
	deaths = 0
	deaths_this_floor = 0
	helper_time_left = 0.0
	level_name = ""


func back_to_title() -> void:
	unload_level()
	level_name = ""
	_set_state(State.TITLE)


func _process(delta: float) -> void:
	if (state == State.PLAYING or state == State.CLEARED) and not get_tree().paused:
		run_seconds += delta
	if helper_time_left > 0.0 and state == State.PLAYING and not get_tree().paused:
		helper_time_left = maxf(0.0, helper_time_left - delta)
		if helper_time_left <= 0.0:
			dismiss_helper()


func load_floor(index: int) -> bool:
	floor_index = clampi(index, 0, FLOORS.size() - 1)
	return load_level(FLOORS[floor_index])


func restart_floor() -> void:
	if level_name != "":
		quick_arrival = true
		load_level(level_name)
		quick_arrival = false


func floor_label(name_of_level: String) -> String:
	if name_of_level == "roof":
		return "ROOF"
	var index: int = FLOORS.find(name_of_level)
	return "LEVEL %d" % (index + 1) if index >= 0 else "TEST"


func next_floor_name() -> String:
	var index: int = FLOORS.find(level_name)
	return FLOORS[index + 1] if index >= 0 and index < FLOORS.size() - 1 else ""


func announce_floor() -> void:
	floor_announced.emit(floor_label(level_name), data.intro if data != null else "")


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
	helper = null
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
	if name_of_level != level_name:
		# A new floor: the death count starts over and any help that was left is gone.
		deaths_this_floor = 0
		helper_time_left = 0.0
	level_name = name_of_level
	kills = 0
	level = LevelBuilder.build(data)
	level_root.add_child(level)
	_place_helper_capsule()
	LevelBuilder.bake_navigation(level, data)
	BulletPool.for_node(level)

	player = PLAYER_SCENE.instantiate()
	level.add_child(player)
	# The player arrives inside the lift, facing its doors.
	var arrival: Transform3D = LevelBuilder.elevator_transform(data, data.player_start)
	player.global_transform = Transform3D(arrival.basis, arrival * Vector3(0, 0.05, 0.2))
	player.died.connect(_on_player_died)

	for spawn: Dictionary in data.spawns:
		spawn_dude(data.cell_center(spawn["cell"], 0.05), spawn["armed"], spawn.get("weapon", &"pistol"))
	if data.boss_cell.x >= 0:
		spawn_boss(data.cell_center(data.boss_cell, 0.05))
	for wave: Dictionary in data.waves:
		_pending_waves.append(wave.duplicate())

	_arm_player_with_super_gun()
	var index: int = FLOORS.find(level_name)
	if index > best_floor and not god_mode:
		best_floor = index
		save_progress()
	TimeManager.reset()
	_set_state(State.PLAYING)
	if helper_time_left > 0.0:
		# Still under contract from before the last death: he rides up with you.
		var out: Vector3 = -arrival.basis.z
		_spawn_helper(data.cell_center(data.front_cell(data.player_start), 0.05) + out * 0.6 + arrival.basis.x * 0.9, arrival.basis).greet_again()
	floor_loaded.emit(data)
	return true


# ---------------------------------------------------------------- super gun and progress

## The Brute is down. The gun appears where he fell and is the player's from now on.
func grant_super_gun(at: Vector3) -> void:
	has_super_gun = true
	save_progress()
	var prize: SuperGun = SuperGun.create()
	entities_root(self).add_child(prize)
	prize.global_position = Vector3(at.x, 1.1, at.z)
	super_gun_granted.emit()


func _arm_player_with_super_gun() -> void:
	if not has_super_gun or player == null:
		return
	var gun: SuperGun = SuperGun.create()
	entities_root(self).add_child(gun)
	player.hands.pick_up(gun)


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "best_floor", best_floor)
	cfg.set_value("run", "has_super_gun", has_super_gun)
	cfg.save(PROGRESS_PATH)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) == OK:
		best_floor = int(cfg.get_value("run", "best_floor", 0))
		has_super_gun = bool(cfg.get_value("run", "has_super_gun", false))


func erase_progress() -> void:
	best_floor = 0
	has_super_gun = false
	save_progress()


# ---------------------------------------------------------------- helper

func wants_helper_capsule() -> bool:
	return deaths_this_floor >= T.helper_deaths_needed and helper_time_left <= 0.0 and AdService.is_available()


func _place_helper_capsule() -> void:
	if not wants_helper_capsule():
		return
	var cell: Vector2i = data.capsule_cell()
	if cell.x < 0:
		return
	var capsule := HelperCapsule.new()
	capsule.name = "HelperCapsule"
	# Under Nav, so the bake carves around it. It faces back toward the lift doors.
	level.get_node(^"Nav").add_child(capsule)
	var toward_lift: Vector3 = data.cell_center(data.front_cell(data.player_start)) - data.cell_center(cell)
	capsule.transform = Transform3D(Basis(Vector3.UP, atan2(-toward_lift.x, -toward_lift.z)), data.cell_center(cell))


## Called by the capsule once the ad has been watched.
func hire_helper(at: Vector3, facing: Basis) -> Helper:
	helper_time_left = T.helper_seconds
	var hired: Helper = _spawn_helper(at, facing)
	hired.greet()
	return hired


func _spawn_helper(at: Vector3, facing: Basis) -> Helper:
	if helper != null and is_instance_valid(helper):
		return helper
	helper = Helper.new()
	helper.name = "Helper"
	entities_root(self).add_child(helper)
	helper.global_transform = Transform3D(facing.orthonormalized(), Vector3(at.x, 0.05, at.z))
	helper_changed.emit(true)
	return helper


func dismiss_helper(floor_is_clear: bool = false) -> void:
	helper_time_left = 0.0
	if helper != null and is_instance_valid(helper):
		helper.leave(floor_is_clear)
	helper = null
	helper_changed.emit(false)


# ---------------------------------------------------------------- enemies

func spawn_dude(at: Vector3, armed: bool, weapon_kind: StringName = &"pistol") -> PinkDude:
	var dude: PinkDude
	if weapon_kind == &"zombie":
		# Buried. He registers himself as an enemy when he climbs out.
		var biter := Zombie.new()
		biter.name = "Biter"
		entities_root(self).add_child(biter)
		biter.global_position = at
		return biter
	if weapon_kind == &"shield":
		dude = ShieldDude.new()
		dude.name = "ShieldDude"
	elif weapon_kind == &"runner":
		dude = Runner.new()
		dude.name = "Runner"
	else:
		dude = DUDE_SCENE.instantiate()
		dude.armed_at_spawn = armed
		dude.weapon_kind = weapon_kind
	_register(dude, at)
	return dude


func spawn_boss(at: Vector3) -> PinkDude:
	var boss: PinkDude
	match data.boss_kind:
		&"brute":
			boss = Brute.new()
		&"warden":
			boss = Warden.new()
		_:
			boss = Director.new()
	boss.name = String(data.boss_kind).capitalize()
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
## A biter has clawed his way up. Now he counts.
func register_risen(biter: Zombie) -> void:
	biter.died.connect(_on_dude_died)
	alive_enemies += 1


func spawn_wave(count: int, armed: int, kind: StringName = &"pistol") -> void:
	if data == null or data.wave_points.is_empty():
		return
	# Start at a random wave point and take a different one for each dude, so a wave
	# comes in from several sides instead of as one clump.
	var first: int = randi() % data.wave_points.size()
	for i: int in count:
		var cell: Vector2i = data.wave_points[(first + i) % data.wave_points.size()]
		var jitter := Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
		var dude: PinkDude = spawn_dude(data.cell_center(cell, 0.05) + jitter, i < armed, kind if i < armed else &"runner" if kind == &"runner" else &"pistol")
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
		dismiss_helper(true)      # the job is done


func _on_player_died() -> void:
	if state != State.PLAYING and state != State.CLEARED:
		return
	_set_state(State.DEAD)
	deaths += 1
	deaths_this_floor += 1
	Sfx.play(&"death")
	var serial: int = _load_serial
	await get_tree().create_timer(T.death_restart_delay, true, false, true).timeout
	if serial == _load_serial and state == State.DEAD:
		restart_floor()
