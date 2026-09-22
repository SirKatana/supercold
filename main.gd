extends Node3D
## Entry scene. Builds environment, light and HUD, then hands over to Game.

const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const TITLE_SCENE: PackedScene = preload("res://ui/title.tscn")
const T: Tuning = preload("res://data/tuning.tres")
const PAUSE_SCENE: PackedScene = preload("res://ui/pause.tscn")
const ENDING_SCENE: PackedScene = preload("res://ui/ending.tscn")

var _title: TitleScreen
var _ending: EndingScreen
var _env: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	_build_environment()
	var root := Node3D.new()
	root.name = "LevelRoot"
	add_child(root)
	Game.level_root = root
	add_child(HUD_SCENE.instantiate())
	add_child(PAUSE_SCENE.instantiate())
	_title = TITLE_SCENE.instantiate()
	add_child(_title)
	_title.start_requested.connect(_start_run)
	_ending = ENDING_SCENE.instantiate()
	add_child(_ending)
	_ending.dismissed.connect(Game.back_to_title)
	Game.state_changed.connect(_on_state_changed)
	Game.floor_loaded.connect(_apply_theme)

	Game.god_mode = _flag("god")
	if _flag("perfprint"):
		_perf_print()
	var level: String = _arg("level", "")
	var level_number: int = _level_from_args()
	if level_number > 0:
		_start_test_run(level_number)
	elif level != "":
		_title.visible = false
		Game.load_level(level)
	else:
		Game.state_changed.emit(Game.State.TITLE)
	if _arg("shot", "") != "":
		_capture.call_deferred(_arg("shot", ""), float(_arg("shot-after", "1.0")))


## Testing: jump straight to a level, skipping the title.
##   ./SuperCold.x86_64 9                  level 9
##   ./SuperCold.x86_64 9 --helper=true    level 9 with the helper hired for free, no deaths, no ad
##   ./SuperCold.x86_64 14 --god=true      cannot die
## Progress is not saved in a test run, so it never moves your real Continue point. From level 11
## on you get the super gun, as you would have by then.
func _start_test_run(level_number: int) -> void:
	_title.visible = false
	Game.testing = true
	if level_number >= 11:
		Game.has_super_gun = true
	Game.start_run(level_number - 1)
	if _flag("helper"):
		Game.free_helper = true
		Game.give_free_helper()
	print("TEST RUN level=%d (%s) helper=%s god=%s" % [level_number, Game.level_name, _flag("helper"), Game.god_mode])


## Every floor has its own colours and light. The first five keep the white look.
func _apply_theme(data: LevelData) -> void:
	var t: Dictionary = data.theme if data != null else {}
	var sky := Color(str(t.get("sky", "edf0f5")))
	_env.background_color = sky
	_env.ambient_light_color = Color(str(t.get("ambient", "ffffff")))
	_env.ambient_light_energy = float(t.get("energy", 0.55))
	_sun.light_energy = float(t.get("sun", 0.45))
	RenderingServer.set_default_clear_color(sky)


func _start_run(from_floor: int) -> void:
	_title.visible = false
	Game.start_run(maxi(from_floor, int(_arg("floor", "0"))))


func _on_state_changed(state: Game.State) -> void:
	var playing: bool = state == Game.State.PLAYING or state == Game.State.CLEARED or state == Game.State.DEAD
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	if state == Game.State.TITLE:
		_title.visible = true
	elif state == Game.State.ENDING:
		_ending.show_stats(Game.run_seconds, Game.deaths)


## Every argument the game was started with: the ones before a `--` and the ones after it.
func _all_args() -> PackedStringArray:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args


## Reads `--name=value` from the command line. A bare `--name` reads as "true".
func _arg(arg_name: String, fallback: String) -> String:
	for a: String in _all_args():
		if a.begins_with("--%s=" % arg_name):
			return a.trim_prefix("--%s=" % arg_name)
		if a == "--%s" % arg_name:
			return "true"
	return fallback


func _flag(arg_name: String) -> bool:
	return _arg(arg_name, "false").to_lower() in ["true", "1", "yes", "on"]


## Testing shortcut: `./SuperCold.x86_64 9` starts on level 9. Returns 0 if no level was given.
func _level_from_args() -> int:
	for a: String in _all_args():
		if a.is_valid_int() and int(a) >= 1 and int(a) <= Game.FLOORS.size():
			return int(a)
	return 0


## Debug aid: `godot4 --path . -- --shot=/tmp/f.png --shot-after=1.5` saves one frame and quits.
## `--perfprint=1`: once a second, what a frame costs. Works in the web build too.
func _perf_print() -> void:
	TimeManager.override_scale = 1.0
	# Switches for pinning down where web frame time goes. Measuring aids only.
	if _flag("norender"):
		get_viewport().disable_3d = true
	if _flag("novideo"):
		for feed: Node in get_tree().root.find_children("MonitorFeed", "VideoStreamPlayer", false, false):
			(feed as VideoStreamPlayer).stop()
	if _flag("nodudes"):
		for dude: Node in get_tree().get_nodes_in_group(&"enemies"):
			dude.queue_free()
	if _flag("nosound"):
		AudioServer.set_bus_mute(0, true)
	if _flag("nohud"):
		for layer: Node in find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
	# Brackets round every script's _process: first and last in the frame.
	var first := Node.new()
	first.process_priority = -100000
	var last := Node.new()
	last.process_priority = 100000
	var span: Dictionary = {"start": 0, "sum": 0, "frames": 0, "gap": 0, "prev_end": 0}
	first.set_script(_bracket_script(true))
	last.set_script(_bracket_script(false))
	first.set_meta(&"span", span)
	last.set_meta(&"span", span)
	add_child(first)
	add_child(last)
	while true:
		await get_tree().create_timer(1.0, true, false, true).timeout
		var n: int = maxi(1, span["frames"])
		print("SPAN scripts %.1f ms  between frames outside scripts %.1f ms" % [span["sum"] / 1000.0 / n, span["gap"] / 1000.0 / n])
		span["sum"] = 0
		span["gap"] = 0
		span["frames"] = 0
		print("PERF fps %d  process %.1f ms  physics %.1f ms  draws %d  objects %d  prims %d  dudes %d" % [
			Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Game.alive_enemies])


func _bracket_script(opening: bool) -> GDScript:
	var src := GDScript.new()
	src.source_code = """extends Node
func _process(_d: float) -> void:
	var span: Dictionary = get_meta(&"span")
	var now: int = Time.get_ticks_usec()
	if %s:
		if span["prev_end"] > 0:
			span["gap"] += now - span["prev_end"]
		span["start"] = now
	else:
		span["sum"] += now - span["start"]
		span["frames"] += 1
		span["prev_end"] = now
""" % ("true" if opening else "false")
	src.reload()
	return src


func _capture(path: String, after: float) -> void:
	await get_tree().create_timer(after, true, false, true).timeout
	if _arg("do", "").begins_with("lift") and _arg("do", "") != "liftarrive" and Game.player != null:
		var lift: Elevator = get_tree().get_first_node_in_group(&"elevator") as Elevator
		if lift != null:
			for node: Node in get_tree().get_nodes_in_group(&"enemies"):
				(node as PinkDude).die()
			var out: Vector3 = -lift.global_transform.basis.z
			Game.player.global_position = lift.global_position + out * 3.4 + lift.global_transform.basis.x * 0.5
			Game.player.look_at(lift.global_position + Vector3(0, 0.0, 0) + out * 0.9)
			if _arg("do", "") == "lift_open":
				await get_tree().create_timer(0.3, true, false, true).timeout
				lift.press()
			await get_tree().create_timer(1.4, true, false, true).timeout
	if (_arg("do", "") == "ram" or _arg("do", "") == "breach") and Game.player != null:
		var ram: Ram = Ram.create()
		Game.entities_root(self).add_child(ram)
		if _arg("do", "") == "breach":
			var target: Vector3 = Game.data.cell_center(Vector2i(5, 3), 0.05)
			Game.player.global_position = target + Vector3(-2.6, 0, 0.6)
			Game.player.look_at(target)
			Game.player.head.rotation.x = 0.0
		Game.player.hands.pick_up(ram)
		await get_tree().create_timer(0.3, true, false, true).timeout
		if _arg("do", "") == "breach":
			Game.player.hands.primary()
			ram.cooldown_left = 0.0
			await get_tree().create_timer(0.4, true, false, true).timeout
			Game.player.hands.primary()
			TimeManager.override_scale = 0.5
			await get_tree().create_timer(0.7, true, false, true).timeout
	if _arg("do", "") == "cleaner" and Game.player != null:
		# Spill something in front of the player and let the cleaner get to work. `--angry=true`
		# makes it the fifth spill.
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			node.queue_free()
		var me: Player = Game.player
		me.global_position += -me.global_transform.basis.z * 3.2
		var spot: Vector3 = me.global_position - me.global_transform.basis.z * 3.0
		if _flag("angry"):
			Game.spills_this_floor = T.cleaner_strikes - 1
		var pool := Puddle.new()
		pool.radius = T.spill_radius
		pool.life = T.spill_seconds
		Game.entities_root(self).add_child(pool)
		pool.global_position = Vector3(spot.x, 0, spot.z)
		Game.report_spill(pool)
		if Game.cleaner != null:
			Game.cleaner.global_position = spot + me.global_transform.basis.x * (0.0 if _flag("angry") else 0.9) + me.global_transform.basis.z * (0.6 if _flag("angry") else 0.0)
		me.head.rotation.x = -0.12
		me.hands.visible = false
		TimeManager.override_scale = 1.0
		await get_tree().create_timer(float(_arg("at", "3.0")), true, false, true).timeout
	if _arg("do", "") == "sign" and Game.player != null:
		# A wet floor sign a little way ahead, turned so both panels show.
		var viewer: Player = Game.player
		viewer.global_position += -viewer.global_transform.basis.z * 3.2
		var placed: WetFloorSign = WetFloorSign.stand(Game.entities_root(self), viewer.global_position - viewer.global_transform.basis.z * 1.7)
		placed.rotation.y = viewer.rotation.y + 1.0
		viewer.head.rotation.x = -0.5
		viewer.hands.visible = false
		await get_tree().create_timer(0.3, true, false, true).timeout
	if _arg("do", "") == "view" and Game.player != null:
		# Stand on one grid cell and look at another: `--cell=12,1 --look=12,5 [--pitch=-5]`.
		var from: PackedStringArray = _arg("cell", "1,1").split(",")
		var to: PackedStringArray = _arg("look", "2,1").split(",")
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			node.queue_free()
		Game.player.global_position = Game.data.cell_center(Vector2i(int(from[0]), int(from[1])), 0.05)
		var target: Vector3 = Game.data.cell_center(Vector2i(int(to[0]), int(to[1])), 0.05)
		Game.player.look_at(Vector3(target.x, Game.player.global_position.y, target.z))
		Game.player.head.rotation.x = deg_to_rad(float(_arg("pitch", "0")))
		Game.player.hands.visible = false
		await get_tree().create_timer(0.3, true, false, true).timeout
	if _arg("do", "") == "door" and Game.player != null:
		# Stand in front of the first door. `--dude=1` puts someone behind it so it swings open.
		var d: Door = get_tree().get_first_node_in_group(&"doors") as Door
		var face: Vector3 = Vector3(0, 0, 1) if d.along_x else Vector3(1, 0, 0)
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			node.queue_free()
		Game.player.global_position = d.global_position + face * float(_arg("back", "3.0")) + Vector3(float(_arg("side", "0.9")), 0.05, 0).rotated(Vector3.UP, 0.0 if d.along_x else PI * 0.5)
		Game.player.look_at(Vector3(d.global_position.x, Game.player.global_position.y, d.global_position.z))
		Game.player.head.rotation.x = -0.08
		Game.player.hands.visible = false
		if _flag("oneleaf"):
			d.take_damage(9, -face, d._visual.global_transform * Vector3(0.5, 1.2, 0.0))
		if _flag("dude"):
			var visitor: PinkDude = Game.spawn_dude(d.global_position - face * 1.0, true)
			visitor.sense_override = true
			TimeManager.override_scale = 1.0
		await get_tree().create_timer(float(_arg("at", "0.4")), true, false, true).timeout
	if _arg("do", "") == "doorbreak" and Game.player != null:
		if _flag("multimesh"):
			Shatter.plain_meshes = false      # compare against the desktop MultiMesh path
		var door: Door = get_tree().get_first_node_in_group(&"doors") as Door
		if door != null:
			var facing: Vector3 = Vector3(0, 0, 1) if door.along_x else Vector3(1, 0, 0)
			Game.player.global_position = door.global_position + facing * 3.2 + Vector3(0, 0.05, 0)
			Game.player.look_at(door.global_position)
			Game.player.head.rotation.x = 0.0
			for node: Node in get_tree().get_nodes_in_group(&"enemies"):
				node.queue_free()
			await get_tree().create_timer(0.4, true, false, true).timeout
			TimeManager.override_scale = 0.5
			door.shatter(-facing)
			await get_tree().create_timer(float(_arg("at", "0.5")), true, false, true).timeout
	if _arg("do", "").begins_with("die") and Game.player != null:
		Game.god_mode = false
		Game.player.global_position = Game.data.cell_center(Vector2i(5, 7), 0.05)
		Game.player._last_hit_direction = Vector3(0.3, 0, 1).normalized()
		Game.player.die()
		await get_tree().create_timer(0.45 if _arg("do", "") == "die_early" else 1.7, true, false, true).timeout
	if _arg("do", "") == "shoot" and Game.player != null:
		var gun: Pistol = Pistol.create()
		Game.entities_root(self).add_child(gun)
		Game.player.hands.pick_up(gun)
		await get_tree().create_timer(0.6, true, false, true).timeout
		Game.player.hands.primary()
		await get_tree().create_timer(1.2, true, false, true).timeout
	if _arg("do", "").begins_with("dude:") and Game.player != null:
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			node.queue_free()
		Game.player.global_position = Game.data.cell_center(Vector2i(3, 8), 0.05)
		Game.player.look_at(Game.data.cell_center(Vector2i(12, 8), 0.05))
		Game.player.head.rotation.x = 0.0
		var cam_at: Vector3 = Game.player.global_position
		var ahead: Vector3 = -Game.player.global_transform.basis.z
		var side: Vector3 = Game.player.global_transform.basis.x
		var near: float = float(_arg("near", "3.4"))
		var kinds: PackedStringArray = _arg("do", "").trim_prefix("dude:").split(",")
		for i: int in kinds.size():
			var dude: PinkDude = Game.spawn_dude(cam_at + ahead * near + side * (i - (kinds.size() - 1) * 0.5) * 1.1, kinds[i] != "none", StringName(kinds[i]))
			dude.sense_override = true
			dude.look_at(Vector3(cam_at.x, dude.global_position.y, cam_at.z) + side * float(_arg("turn", "3.0")))
			dude.aiming = i % 2 == 0
			dude.desired_velocity = Vector3.ZERO if i % 2 == 0 else -dude.global_transform.basis.z * 3.0
			dude._walk_phase = 1.3
			dude.set_physics_process(false)
			for f: int in 30:
				dude._animate(1.0 / 60.0)
		Game.player.hands.visible = false
		if _flag("kill"):
			# Shoot everyone in the line-up, then wait a moment so things are in the air.
			TimeManager.override_scale = 1.0
			for node: Node in get_tree().get_nodes_in_group(&"enemies"):
				if not node.is_queued_for_deletion():
					(node as PinkDude).on_bullet_hit(null, (node as PinkDude).global_position + Vector3.UP, Vector3.UP)
			await get_tree().create_timer(0.45, true, false, true).timeout
		await get_tree().create_timer(0.2, true, false, true).timeout
	if (_arg("do", "") == "barrel" or _arg("do", "").begins_with("boom")) and Game.player != null:
		Game.player.global_position = Game.data.cell_center(Vector2i(3, 8), 0.05)
		Game.player.look_at(Game.data.cell_center(Vector2i(12, 8), 0.05))
		Game.player.head.rotation.x = -0.08
		Game.player.hands.visible = false
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			node.queue_free()
		for node: Node in get_tree().get_nodes_in_group(&"barrels"):
			node.queue_free()
		var ahead: Vector3 = -Game.player.global_transform.basis.z
		var barrel: GasBarrel = GasBarrel.create()
		Game.entities_root(self).add_child(barrel)
		var near: float = 2.2 if _arg("do", "") == "barrel" else 7.0
		barrel.global_position = Game.player.global_position * Vector3(1, 0, 1) + ahead * near
		barrel.rotation.y = 0.5
		if _arg("do", "").begins_with("boom"):
			for i: int in 3:
				var d: PinkDude = Game.spawn_dude(barrel.global_position + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 2.4 + Vector3(0, 0.05, 0), true)
				d.sense_override = true
			await get_tree().create_timer(0.15, true, false, true).timeout
			TimeManager.override_scale = 1.0
			barrel.explode()
			await get_tree().create_timer(float(_arg("do", "").trim_prefix("boom:")) if _arg("do", "").contains(":") else 0.3, true, false, true).timeout
		else:
			await get_tree().create_timer(0.2, true, false, true).timeout
	if _arg("do", "") == "shieldworn" and Game.player != null:
		Game.player.global_position = Game.data.cell_center(Vector2i(3, 8), 0.05)
		Game.player.look_at(Game.data.cell_center(Vector2i(12, 8), 0.05))
		Game.player.head.rotation.x = 0.0
		var worn: Shield = Shield.create()
		Game.entities_root(self).add_child(worn)
		worn.release_to_floor(Game.player.global_position + Vector3(0.5, 0, 0))
		Game.player.hands.toggle_shield()
		var sidearm: Pistol = Pistol.create()
		Game.entities_root(self).add_child(sidearm)
		Game.player.hands.pick_up(sidearm)
		await get_tree().create_timer(0.2, true, false, true).timeout
	if (_arg("do", "") == "capsule" or _arg("do", "") == "helper") and Game.player != null:
		Game.deaths_this_floor = 3
		Game.fast_elevators = true
		Game.load_level(Game.level_name)
		var capsule: HelperCapsule = get_tree().get_first_node_in_group(&"helper_capsule") as HelperCapsule
		var out: Vector3 = -capsule.global_transform.basis.z
		Game.player.global_position = capsule.global_position + out * 3.6 + capsule.global_transform.basis.x * 0.9 + Vector3(0, 0.05, 0)
		Game.player.look_at(capsule.global_position + Vector3(0, 0.0, 0))
		Game.player.head.rotation.x = 0.06
		Game.player.hands.visible = false
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			(node as PinkDude).sense_override = true
		if _arg("do", "") == "helper":
			AdService.auto_result = 1
			HelperVoice.tts_enabled = false
			capsule.press()
			await get_tree().create_timer(0.9, true, false, true).timeout
		else:
			await get_tree().create_timer(1.4, true, false, true).timeout
	if _arg("do", "") == "ad" and Game.player != null:
		AdService.show_rewarded()
		await get_tree().create_timer(float(_arg("ad-at", "4.0")), true, false, true).timeout
	if _arg("do", "").begins_with("tour") and Game.player != null:
		# Stand a few cells out of the lift, a little above head height, looking across the floor.
		var d: LevelData = Game.data
		var front: Vector3 = d.cell_center(d.front_cell(d.player_start), 0.05)
		var centre := Vector3(d.width * d.cell_size * 0.5, 0.05, d.height * d.cell_size * 0.5)
		if _arg("do", "").contains(":"):
			var parts: PackedStringArray = _arg("do", "").trim_prefix("tour:").split(",")
			front = d.cell_center(Vector2i(int(parts[0]), int(parts[1])), 0.05)
			if parts.size() >= 4:
				centre = d.cell_center(Vector2i(int(parts[2]), int(parts[3])), 0.05)
		Game.player.global_position = front
		Game.player.look_at(Vector3(centre.x, front.y, centre.z))
		Game.player.head.rotation.x = float(_arg("pitch", "-0.10"))
		Game.player.hands.visible = false
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			(node as PinkDude).sense_override = true
		await get_tree().create_timer(0.5, true, false, true).timeout
	if _arg("do", "").begins_with("fx:") and Game.player != null:
		var what: String = _arg("do", "").trim_prefix("fx:")
		Game.player.global_position = Game.data.cell_center(Vector2i(3, 8), 0.05)
		Game.player.look_at(Game.data.cell_center(Vector2i(12, 8), 0.05))
		Game.player.head.rotation.x = -0.04
		Game.player.hands.visible = false
		for group: StringName in [&"enemies", &"barrels", &"buried"]:
			for node: Node in get_tree().get_nodes_in_group(group):
				node.queue_free()
		var ahead: Vector3 = -Game.player.global_transform.basis.z
		var side: Vector3 = Game.player.global_transform.basis.x
		var base: Vector3 = Game.player.global_position
		var cast: Array[PinkDude] = []
		var kinds: Array[StringName] = [&"pistol"]
		if what != "brute":
			kinds.append(&"rifle")
			kinds.append(&"shield")
		for i: int in kinds.size():
			var d: PinkDude = Game.spawn_dude(base + ahead * 4.2 + side * (i - 1) * 1.6, true, kinds[i])
			d.sense_override = true
			d.look_at(Vector3(base.x, d.global_position.y, base.z))
			d.set_physics_process(false)
			d._animate(0.0)
			cast.append(d)
		TimeManager.override_scale = 1.0
		match what:
			"melt":
				for d: PinkDude in cast:
					d.on_laser(ahead)
				await get_tree().create_timer(0.75, true, false, true).timeout
			"freeze":
				FreezeBlast.go(Game.entities_root(self), base + ahead * 4.2 + Vector3.UP * 0.5)
				await get_tree().create_timer(0.35, true, false, true).timeout
			"choke":
				for d: PinkDude in cast:
					d.set_physics_process(true)
				var stink := FartCloud.new()
				Game.entities_root(self).add_child(stink)
				stink.global_position = base + ahead * 4.6 + Vector3.UP * 1.1
				stink.burst()
				await get_tree().create_timer(float(_arg("at", "1.5")), true, false, true).timeout
			"zombie":
				for d: PinkDude in cast:
					d.queue_free()
				for i: int in 3:
					Game.spawn_dude(base + ahead * 3.6 + side * (i - 1) * 1.5, true, &"zombie")
				await get_tree().create_timer(float(_arg("at", "1.0")), true, false, true).timeout
			"brute":
				var brute := Brute.new()
				Game.entities_root(self).add_child(brute)
				brute.global_position = base + ahead * 5.5 - side * 0.4
				brute.sense_override = true
				brute.look_at(Vector3(base.x, brute.global_position.y, base.z))
				brute.set_physics_process(false)
				brute._animate(0.0)
				cast[0].global_position = base + ahead * 5.5 - side * 3.0
				cast[0]._animate(0.0)
				await get_tree().create_timer(0.3, true, false, true).timeout
	if _arg("do", "") == "scope" and Game.player != null:
		Game.player.global_position = Game.data.cell_center(Vector2i(3, 8), 0.05)
		Game.player.look_at(Game.data.cell_center(Vector2i(12, 8), 0.05))
		Game.player.head.rotation.x = 0.0
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			(node as PinkDude).sense_override = true
		var target: PinkDude = Game.spawn_dude(Game.player.global_position - Game.player.global_transform.basis.z * 16.0, true, &"rifle")
		target.sense_override = true
		var scoped: SniperRifle = SniperRifle.create()
		Game.entities_root(self).add_child(scoped)
		Game.player.hands.pick_up(scoped)
		Game.player.head.rotation.x = 0.045
		Input.action_press(&"secondary")
		await get_tree().create_timer(0.8, true, false, true).timeout
	if _arg("do", "") == "bullet" and Game.player != null:
		Game.player.global_position = Game.data.cell_center(Vector2i(3, 8), 0.05)
		Game.player.look_at(Game.data.cell_center(Vector2i(12, 8), 0.05))
		Game.player.head.rotation.x = 0.0
		Game.player.hands.visible = false
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			node.queue_free()
		var eye: Vector3 = Game.player.aim_origin()
		var ahead: Vector3 = Game.player.aim_direction()
		var side: Vector3 = Game.player.global_transform.basis.x
		TimeManager.override_scale = 0.3
		var pool: BulletPool = BulletPool.for_node(Game.player)
		pool.fire(eye + ahead * 1.1 - side * 1.2, (side + ahead * 0.15).normalized(), null)
		pool.fire(eye + ahead * 1.5 - side * 1.0 + Vector3.UP * 0.2, (side + ahead * 0.1).normalized(), null, 0.6)
		await get_tree().create_timer(0.30, true, false, true).timeout
	if _arg("do", "") == "guard" and Game.player != null:
		Game.fast_elevators = true
		Game.carried = {"kind": &"rifle", "ammo": 30}
		Game.load_level(Game.level_name)
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			(node as PinkDude).sense_override = true
		var g: SecurityGuard = Game.guard
		Game.player.global_position = g.global_position - g.global_transform.basis.z * float(_arg("near", "3.0")) + Vector3(0, 0.05, 0)
		Game.player.look_at(g.global_position)
		Game.player.head.rotation.x = 0.0
		if _flag("chase"):
			g._open_fire()
			TimeManager.override_scale = 1.0
			await get_tree().create_timer(0.45, true, false, true).timeout
			Game.player.look_at(g.global_position)
			Game.player.head.rotation.x = 0.0
		await get_tree().create_timer(0.6, true, false, true).timeout
	if _arg("do", "") == "liftarrive" and Game.player != null:
		Game.fast_elevators = false
		var exit_lift: Elevator = get_tree().get_first_node_in_group(&"elevator") as Elevator
		var out: Vector3 = -exit_lift.global_transform.basis.z
		Game.player.global_position = exit_lift.global_position + out * 4.2 + exit_lift.global_transform.basis.x * 1.2 + Vector3(0, 0.05, 0)
		Game.player.look_at(exit_lift.global_position + Vector3(0, 0.2, 0))
		Game.player.hands.visible = false
		if _arg("at", "") != "before":
			for node: Node in get_tree().get_nodes_in_group(&"enemies"):
				(node as PinkDude).die()
			await get_tree().create_timer(float(_arg("at", "1.2")), true, false, true).timeout
		else:
			await get_tree().create_timer(0.3, true, false, true).timeout
	if _arg("do", "") == "pour" and Game.player != null:
		Game.player.global_position = Game.data.cell_center(Vector2i(3, 8), 0.05)
		Game.player.look_at(Game.data.cell_center(Vector2i(12, 8), 0.05))
		Game.player.head.rotation.x = -0.28
		for group: StringName in [&"enemies", &"barrels"]:
			for node: Node in get_tree().get_nodes_in_group(group):
				node.queue_free()
		var ahead: Vector3 = -Game.player.global_transform.basis.z
		for i: int in 2:
			var d: PinkDude = Game.spawn_dude(Game.player.global_position + ahead * 3.2 + Game.player.global_transform.basis.x * (i - 0.5) * 1.6, true, &"rifle" if i == 0 else &"pistol")
			d.sense_override = true
		var pail: WaterBucket = WaterBucket.create()
		Game.entities_root(self).add_child(pail)
		Game.player.hands.pick_up(pail)
		await get_tree().create_timer(0.3, true, false, true).timeout
		TimeManager.override_scale = 1.0
		Game.player.hands.primary()
		await get_tree().create_timer(1.3, true, false, true).timeout
	if _arg("do", "").begins_with("item:") and Game.player != null:
		var thing: Pickup = LevelBuilder.create_pickup(StringName(_arg("do", "").trim_prefix("item:")))
		Game.entities_root(self).add_child(thing)
		Game.player.hands.pick_up(thing)
		await get_tree().create_timer(0.2, true, false, true).timeout
	if _arg("do", "") == "cabin" and Game.player != null:
		# Inside the arrival lift: `--step` metres toward the doors, `--pitch` and `--yaw` in degrees.
		Game.player.global_position += -Game.player.global_transform.basis.z * float(_arg("step", "0"))
		Game.player.rotation.y += deg_to_rad(float(_arg("yaw", "0")))
		Game.player.head.rotation.x = deg_to_rad(float(_arg("pitch", "0")))
		await get_tree().create_timer(0.3, true, false, true).timeout
	if _arg("do", "") == "props" and Game.player != null:
		# A desk, a cabinet and the three throwables, lined up close to the camera.
		for group: StringName in [&"enemies"]:
			for node: Node in get_tree().get_nodes_in_group(group):
				node.queue_free()
		var eye: Player = Game.player
		eye.global_position += -eye.global_transform.basis.z * 3.4      # out of the lift
		var ahead: Vector3 = -eye.global_transform.basis.z
		var right: Vector3 = eye.global_transform.basis.x
		var at: Vector3 = eye.global_position + ahead * 2.6
		var desk: StaticBody3D = LevelBuilder.make_box(Furniture.DESK_SIZE, LevelBuilder.prop_material)
		Furniture.dress(desk, Furniture.desk_mesh(), LevelBuilder.prop_material)
		Game.entities_root(self).add_child(desk)
		desk.global_position = at - right * 0.75 + Vector3(0, 0.5, 0)
		desk.rotation.y = eye.rotation.y + 0.5
		var cabinet: StaticBody3D = LevelBuilder.make_box(Furniture.CABINET_SIZE, LevelBuilder.prop_material)
		Furniture.dress(cabinet, Furniture.cabinet_mesh(), LevelBuilder.prop_material)
		Game.entities_root(self).add_child(cabinet)
		cabinet.global_position = at + right * 0.95 - ahead * 0.5 + Vector3(0, 0.45, 0)
		cabinet.rotation.y = eye.rotation.y - 0.35
		var kinds: Array[StringName] = [&"bottle", &"keyboard", &"mug"]
		for i: int in kinds.size():
			var item: Pickup = LevelBuilder.create_pickup(kinds[i])
			Game.entities_root(self).add_child(item)
			item.global_position = cabinet.global_position + Vector3(0, 0.45 + Pickup.REST_HEIGHT, 0) + right * (i - 1) * 0.2 - ahead * (0.1 if i == 1 else -0.12)
			item.rotation.y = eye.rotation.y + 0.6
		eye.head.rotation.x = -0.32
		eye.hands.visible = false
		if _flag("monitor"):
			# Sit down at the desk: straight on to one of its screens, with the video running.
			desk.rotation.y = eye.rotation.y
			desk.global_position = eye.global_position + ahead * 1.55 + Vector3(0, 0.5, 0)
			eye.global_position += right * Furniture.MONITOR_X * -1.0
			eye.head.rotation.x = -0.18
			TimeManager.override_scale = 1.0
			await get_tree().create_timer(float(_arg("at", "6.0")), true, false, true).timeout
		await get_tree().create_timer(0.3, true, false, true).timeout
	if _arg("do", "").begins_with("gun:") and Game.player != null:
		var gun: Gun = PinkDude.create_gun(StringName(_arg("do", "").trim_prefix("gun:")))
		Game.entities_root(self).add_child(gun)
		Game.player.hands.pick_up(gun)
		await get_tree().create_timer(0.2, true, false, true).timeout
	if _arg("do", "").begins_with("model:") and Game.player != null:
		# A turntable view: the gun floats side-on in front of the camera.
		var show: Gun = PinkDude.create_gun(StringName(_arg("do", "").trim_prefix("model:")))
		Game.entities_root(self).add_child(show)
		show.state = Pickup.State.HELD
		var cam: Camera3D = Game.player.camera
		show.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, 0.0),
			cam.global_position - cam.global_transform.basis.z * 0.75 - cam.global_transform.basis.x * 0.12)
		show.global_transform.basis = cam.global_transform.basis * Basis(Vector3.UP, -PI * 0.5 + 0.35) * Basis(Vector3.FORWARD, 0.12)
		Game.player.hands.visible = false
		await get_tree().create_timer(0.2, true, false, true).timeout
	if _arg("do", "") == "hold" and Game.player != null:
		var pistol: Pistol = Pistol.create()
		Game.entities_root(self).add_child(pistol)
		Game.player.hands.pick_up(pistol)
		await get_tree().create_timer(0.1, true, false, true).timeout
	if _arg("do", "") == "punch" and Game.player != null:
		Game.player.hands.punch()
		await get_tree().create_timer(0.06, true, false, true).timeout
	await RenderingServer.frame_post_draw
	if OS.has_feature("web"):
		print("CAPTURE_READY")      # tools/web_check.mjs takes the picture when it sees this
		return
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _build_environment() -> void:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.94, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.35
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = false
	add_child(sun)
