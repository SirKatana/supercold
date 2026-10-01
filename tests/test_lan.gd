extends "res://tests/test_case.gd"
## Two games on one machine, talking to each other over the loopback the same way two machines
## on a wifi would. The host simulates; the joiner sends what it is pressing.


func after_each() -> void:
	Net.close()
	TimeManager.override_scale = -1.0


func test_hosting_gives_a_code_and_opens_a_port() -> void:
	if Net.lan_address() == "":
		check(true, "no network on this machine: nothing to test")
		return
	var given: String = Net.host()
	check(given != "", "a code came back: %s" % given)
	check_eq(given.length(), 6, "six characters")
	check_eq(Net.role, Net.Role.HOSTING, "and the game is open")
	check(Net.is_host(), "this machine owns the simulation")
	check_eq(Net.players.size(), 1, "with nobody else in it yet")


func test_a_rubbish_code_is_refused_before_anything_is_dialled() -> void:
	var told: Dictionary = {"why": ""}
	var on_fail: Callable = func(why: String) -> void: told["why"] = why
	Net.failed.connect(on_fail)
	check(not Net.join("NOPE"), "a short code is not dialled")
	check(told["why"] != "", "and it says why: %s" % told["why"])
	check_eq(Net.role, Net.Role.OFF, "nothing was opened")
	Net.failed.disconnect(on_fail)


func test_the_world_moves_when_any_player_moves() -> void:
	# The fold is a maximum: one player standing still does not hold the world back while
	# another one runs.
	TimeManager.override_scale = -1.0
	TimeManager.report_move(0.0)
	TimeManager.report_move(T.walk_speed)
	await wait_frames(2)
	var running: float = TimeManager.compute_target(T.walk_speed, 0.0, 0.0, T)
	check(running >= 0.95, "somebody running means the world runs (%.2f)" % running)
	var standing: float = TimeManager.compute_target(0.0, 0.0, 0.0, T)
	check(standing <= T.min_scale + 0.001, "and everybody still means it crawls (%.2f)" % standing)


func test_a_relayed_player_takes_its_orders_from_the_packet() -> void:
	Game.god_mode = true
	check(Game.load_level("test_room"), "a level loads")
	await wait_physics(2)
	var stand_in := Player.new()
	Game.entities_root(self).add_child(stand_in)
	stand_in.global_position = Game.player.global_position + Vector3(2, 0, 0)
	stand_in.use_relayed = true
	await wait_physics(2)
	var started: Vector3 = stand_in.global_position
	stand_in.relayed = {"move": Vector2(0, -1)}
	for step: int in 30:
		await wait_physics(1)
	check(stand_in.global_position.distance_to(started) > 0.3,
		"it walked where the packet said (%.2f m)" % stand_in.global_position.distance_to(started))
	stand_in.queue_free()
	Game.god_mode = false
	Game.unload_level()
