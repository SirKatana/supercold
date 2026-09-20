extends Node3D
## Entry scene. Builds environment, light and HUD, then hands over to Game.

const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const TITLE_SCENE: PackedScene = preload("res://ui/title.tscn")
const PAUSE_SCENE: PackedScene = preload("res://ui/pause.tscn")
const ENDING_SCENE: PackedScene = preload("res://ui/ending.tscn")

var _title: TitleScreen
var _ending: EndingScreen


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

	Game.god_mode = _arg("god", "") != ""
	var level: String = _arg("level", "")
	if level != "":
		_title.visible = false
		Game.load_level(level)
	else:
		Game.state_changed.emit(Game.State.TITLE)
	if _arg("shot", "") != "":
		_capture.call_deferred(_arg("shot", ""), float(_arg("shot-after", "1.0")))


func _start_run() -> void:
	_title.visible = false
	Game.start_run(int(_arg("floor", "0")))


func _on_state_changed(state: Game.State) -> void:
	var playing: bool = state == Game.State.PLAYING or state == Game.State.CLEARED or state == Game.State.DEAD
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	if state == Game.State.TITLE:
		_title.visible = true
	elif state == Game.State.ENDING:
		_ending.show_stats(Game.run_seconds, Game.deaths)


## Reads `--name=value` from the arguments after `--` on the command line.
func _arg(arg_name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.trim_prefix("--%s=" % arg_name)
	return fallback


## Debug aid: `godot4 --path . -- --shot=/tmp/f.png --shot-after=1.5` saves one frame and quits.
func _capture(path: String, after: float) -> void:
	await get_tree().create_timer(after, true, false, true).timeout
	if _arg("do", "").begins_with("lift") and Game.player != null:
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
		var kinds: PackedStringArray = _arg("do", "").trim_prefix("dude:").split(",")
		for i: int in kinds.size():
			var dude: PinkDude = Game.spawn_dude(cam_at + ahead * 3.4 + side * (i - (kinds.size() - 1) * 0.5) * 1.5, kinds[i] != "none", StringName(kinds[i]))
			dude.sense_override = true
			dude.look_at(Vector3(cam_at.x, dude.global_position.y, cam_at.z) + side * 3.0)
			dude.aiming = i % 2 == 0
			dude.desired_velocity = Vector3.ZERO if i % 2 == 0 else -dude.global_transform.basis.z * 3.0
			dude._walk_phase = 1.3
			dude.set_physics_process(false)
			for f: int in 30:
				dude._animate(1.0 / 60.0)
		Game.player.hands.visible = false
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
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _build_environment() -> void:
	var env := Environment.new()
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
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = false
	add_child(sun)
