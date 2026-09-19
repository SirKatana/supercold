extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.fast_elevators = true


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Sfx.stop_music(0.01)
	Game.unload_level()


func _exit_lift() -> Elevator:
	return get_tree().get_first_node_in_group(&"elevator") as Elevator


func _kill_everyone() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()


func test_door_direction_prefers_a_wall_at_the_back() -> void:
	var d: LevelData = LevelParser.parse("#####\n#P..#\n#..X#\n#####")
	check_eq(d.door_direction(Vector2i(1, 1)), Vector2i.RIGHT, "start lift against the west wall opens east")
	check_eq(d.door_direction(Vector2i(3, 2)), Vector2i.LEFT, "exit lift against the east wall opens west")
	check_eq(d.front_cell(Vector2i(3, 2)), Vector2i(2, 2), "front cell is the one at the doors")


func test_player_arrives_inside_the_lift_facing_its_doors() -> void:
	check(Game.load_level("f2_offices"), "level loads")
	await wait_physics(2)
	var arrival: Elevator = get_tree().get_first_node_in_group(&"arrival") as Elevator
	check(arrival != null, "arrival lift exists")
	check(Game.player.global_position.distance_to(arrival.global_position) < 0.6, "player starts in the cabin")
	var out: Vector3 = -arrival.global_transform.basis.z
	check(Game.player.aim_direction().dot(out) > 0.95, "player faces out through the doors")
	var front: Vector3 = Game.data.cell_center(Game.data.front_cell(Game.data.player_start))
	check((front - arrival.global_position).normalized().dot(out) > 0.95, "doors open onto the front cell")


func test_button_does_nothing_but_buzz_while_enemies_live() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(2)
	var lift: Elevator = _exit_lift()
	check_eq(lift.phase, Elevator.Phase.LOCKED, "locked")
	lift.button.on_punched(self, Vector3.ZERO)
	await wait_frames(10)
	check_eq(lift.phase, Elevator.Phase.LOCKED, "still locked")
	check(lift.door_open < 0.01, "doors stay shut")


func test_button_works_by_punch_bullet_and_thrown_object() -> void:
	for how: String in ["punch", "bullet", "throw"]:
		check(Game.load_level("test_doors"), "level loads")
		await wait_physics(2)
		_kill_everyone()
		await wait_physics(2)
		var lift: Elevator = _exit_lift()
		check_eq(lift.phase, Elevator.Phase.READY, "%s: ready once the floor is clear" % how)
		var target: Vector3 = lift.button.global_position
		var out: Vector3 = -lift.global_transform.basis.z
		match how:
			"punch":
				lift.button.on_punched(self, target)
			"bullet":
				BulletPool.for_node(Game.player).fire(target + out * 3.0, -out, null)
			"throw":
				var item: Throwable = Throwable.create(&"stapler")
				Game.entities_root(self).add_child(item)
				item.throw_from(target + out * 2.0, -out * T.throw_speed, null)
		await wait_physics(40)
		check(lift.phase == Elevator.Phase.OPENING or lift.phase == Elevator.Phase.OPEN, "%s opens the lift" % how)
		check(lift.door_open > 0.9, "%s: doors slid open" % how)


func test_ride_plays_music_and_loads_the_next_floor() -> void:
	check(Game.load_floor(0), "lobby loads")
	await wait_physics(2)
	_kill_everyone()
	await wait_physics(2)
	var lift: Elevator = _exit_lift()
	lift.press()
	await wait_frames(10)
	check_eq(lift.phase, Elevator.Phase.OPEN, "open")
	check(not Sfx.is_music_wanted(), "no music before the ride")
	var state: Dictionary = {"rode": false}
	lift.ride_started.connect(func() -> void: state["rode"] = true)
	Game.player.global_position = lift.global_position + Vector3(0, 0.05, 0)
	for i: int in 120:
		await wait_physics(1)
		if Game.level_name == "f2_offices":
			break
	check(state["rode"], "doors closed and the ride began")
	check_eq(Game.level_name, "f2_offices", "arrived on the next floor")
	check(Game.player != null and Game.player.alive, "fresh player in the next lift")


func test_music_stream_is_a_seamless_loop() -> void:
	var music: AudioStreamWAV = SfxSynth.build_music()
	check_eq(music.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loops")
	check_near(music.get_length(), 9.6, 0.05, "sixteen beats at 100 bpm")
	check_eq(music.loop_end * 2, music.data.size(), "loop covers the whole clip")


func test_stepping_out_announces_the_level() -> void:
	check(Game.load_level("f3_servers"), "level loads")
	await wait_physics(3)
	var heard: Dictionary = {"label": "", "count": 0}
	var on_announce: Callable = func(label: String, _intro: String) -> void:
		heard["label"] = label
		heard["count"] += 1
	Game.floor_announced.connect(on_announce)
	check_eq(heard["count"], 0, "nothing announced while still in the lift")
	Input.action_press(&"move_forward")
	await wait_physics(50)
	Input.action_release(&"move_forward")
	check_eq(heard["label"], "LEVEL 3", "the third floor is LEVEL 3")
	# Walking back in and out must not announce again.
	Input.action_press(&"move_back")
	await wait_physics(50)
	Input.action_release(&"move_back")
	Input.action_press(&"move_forward")
	await wait_physics(50)
	Input.action_release(&"move_forward")
	check_eq(heard["count"], 1, "announced exactly once")
	Game.floor_announced.disconnect(on_announce)


func test_floor_labels() -> void:
	check_eq(Game.floor_label("f1_lobby"), "LEVEL 1", "lobby")
	check_eq(Game.floor_label("f5_executive"), "LEVEL 5", "executive")
	check_eq(Game.floor_label("roof"), "ROOF", "roof")


func test_dudes_cannot_see_into_a_closed_lift() -> void:
	Game.fast_elevators = false
	check(Game.load_level("f1_lobby"), "level loads")
	await wait_physics(3)
	var arrival: Elevator = get_tree().get_first_node_in_group(&"arrival") as Elevator
	check(arrival.door_open < 0.05, "doors start shut")
	var space: PhysicsDirectSpaceState3D = arrival.get_world_3d().direct_space_state
	var outside: Vector3 = arrival.global_position - arrival.global_transform.basis.z * 3.0 + Vector3(0, 1.5, 0)
	check(not Sight.is_clear(space, outside, Game.player.chest_position()), "closed doors block sight")
