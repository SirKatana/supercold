extends "res://tests/test_case.gd"
## Lots of guys, and rounds that meet a running player: the things that make stopping matter.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.fast_elevators = true
	Game.start_run_state_for_tests()
	Game.reinforcements_enabled = true


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.reinforcements_enabled = false
	Game.start_run_state_for_tests()
	Game.unload_level()


func _living() -> Array:
	var out: Array = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if (node as PinkDude).alive:
			out.append(node)
	return out


func test_a_round_is_aimed_where_a_running_player_will_be() -> void:
	var origin := Vector3(0, 1.4, 0)
	var chest := Vector3(0, 1.2, -12)
	var still: Vector3 = PinkDude.lead_point(origin, chest, Vector3.ZERO, T.bullet_speed, 1.0)
	check(still.distance_to(chest) < 0.001, "standing still, he aims at you")
	var running: Vector3 = PinkDude.lead_point(origin, chest, Vector3(T.walk_speed, 3.0, 0), T.bullet_speed, 1.0)
	var flight: float = origin.distance_to(chest) / T.bullet_speed
	check(absf(running.x - T.walk_speed * flight) < 0.01, "running, he aims a full flight time ahead of you")
	check(absf(running.y - chest.y) < 0.001, "a jump does not throw his aim")
	check(T.dude_lead_min > 0.5, "every shot leads by most of the way: a straight run is not a dodge")


func test_more_rounds_in_the_air_than_before() -> void:
	check(T.dude_cadence <= 1.0, "a shot a second or better")
	check(T.dude_aim_time <= 0.5, "and a shorter telegraph")
	check(T.gunshot_hearing >= 40.0, "a gunshot brings the floor")


func test_every_kill_is_answered_until_the_budget_runs_out() -> void:
	check(Game.load_floor(2), "server room loads")
	await wait_physics(3)
	var strength: int = Game.alive_enemies
	check_eq(Game.reinforcements_left, int(ceilf(strength * T.reinforce_ratio)), "as many again are waiting")
	check_eq(Game.enemies_left(), strength + Game.reinforcements_left, "and the lift screen counts them")
	await wait_physics(240)
	check_eq(Game.alive_enemies, strength, "nobody arrives before the shooting starts")
	var budget: int = Game.reinforcements_left
	(_living()[0] as PinkDude).die()
	for i: int in 400:
		await wait_physics(1)
		if Game.reinforcements_left < budget:
			break
	check_eq(Game.reinforcements_left, budget - 1, "one came")
	check_eq(Game.alive_enemies, strength, "back to full strength")
	var newest: PinkDude = _living()[-1]
	check(newest.alerted, "and he already knows where you are")
	check(not Sight.is_clear(Game.player.get_world_3d().direct_space_state, newest.global_position + Vector3(0, 1.5, 0), Game.player.chest_position()) \
		or newest.global_position.distance_to(Game.player.global_position) >= T.reinforce_min_distance, "he did not pop up in front of you")


func test_the_floor_is_not_clear_while_more_are_coming() -> void:
	check(Game.load_floor(0), "lobby loads")
	await wait_physics(3)
	check(Game.reinforcements_left > 0 and Game.reinforcements_left < Game.alive_enemies, "the lobby goes easy: half as many again")
	var cleared: Dictionary = {"yes": false}
	Game.floor_cleared.connect(func() -> void: cleared["yes"] = true, CONNECT_ONE_SHOT)
	for node: Node in _living():
		(node as PinkDude).die()
	await wait_physics(2)
	check(not cleared["yes"], "killing the first lot does not clear the floor")
	check(not (get_tree().get_first_node_in_group(&"elevator") as Elevator).present, "and the lift has not come")
	for i: int in 3000:
		await wait_physics(1)
		for node: Node in _living():
			(node as PinkDude).die()
		if cleared["yes"]:
			break
	check(cleared["yes"], "it clears when the last reinforcement is dead")
	check_eq(Game.reinforcements_left, 0, "budget spent")


func test_boss_floors_bring_their_own_company() -> void:
	check(Game.load_floor(9), "the vault loads")
	await wait_physics(2)
	check_eq(Game.reinforcements_left, 0, "no reinforcements on a boss floor")
