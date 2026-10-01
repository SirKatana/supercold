extends "res://tests/test_case.gd"
## The security room has to be full of guards who are actually standing there.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.back_to = ""
	check(Game.load_level("f2_offices"), "a floor loads")
	await wait_physics(3)
	Game.take_me_to_the_lair(&"security")
	await wait_physics(6)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.back_to = ""
	Game.unload_level()


func test_they_are_posted_and_armed_and_angry() -> void:
	var seen: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"security"):
		var guard: SecurityGuard = node
		check(guard.global_position.length() > 0.5, "%s is somewhere real" % guard.name)
		check(guard.mode == SecurityGuard.Mode.FIRING, "%s is not waiting to be provoked" % guard.name)
		seen += 1
	check(seen >= T.lair_guards, "all twenty are here (%d)" % seen)


func test_they_are_spread_round_the_room_not_stacked_up() -> void:
	var places: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group(&"security"):
		places.append((node as SecurityGuard).global_position)
	var touching: int = 0
	for i: int in places.size():
		for j: int in range(i + 1, places.size()):
			if places[i].distance_to(places[j]) < 0.4:
				touching += 1
	check(touching == 0, "nobody is standing inside anybody else (%d pairs)" % touching)


func test_dying_in_there_puts_you_back_on_your_floor() -> void:
	check(Game.in_a_lair(), "you are in the security room")
	Game.restart_floor()
	await wait_physics(4)
	check_eq(Game.level_name, "f2_offices", "and you wake up where you got in the lift")
