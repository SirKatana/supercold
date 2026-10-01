extends "res://tests/test_case.gd"
## The staff room has to be full of people who actually do something.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.back_to = ""
	check(Game.load_level("f6_cafeteria"), "a floor loads")
	await wait_physics(3)
	Game.take_me_to_the_lair(&"cleaner")
	await wait_physics(6)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.back_to = ""
	Game.unload_level()


func test_they_are_posed_and_standing_where_they_were_put() -> void:
	var seen: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"cleaners"):
		var mop: Cleaner = node
		check(mop._on_duty, "%s is on duty" % mop.name)
		check(mop.hostile, "and wants a word")
		# A cleaner who never runs his step is a heap of parts at the world origin.
		check(mop.global_position.length() > 0.5, "%s is somewhere real" % mop.name)
		seen += 1
	check(seen >= T.lair_cleaners, "all of them are here (%d)" % seen)


func test_they_come_after_you() -> void:
	var mop: Cleaner = get_tree().get_first_node_in_group(&"cleaners") as Cleaner
	check(mop != null, "one of them")
	Game.player.global_position = mop.global_position + Vector3(5, 0, 0)
	await wait_physics(2)
	var started: float = mop.global_position.distance_to(Game.player.global_position)
	for step: int in 180:
		await wait_physics(1)
	var ended: float = mop.global_position.distance_to(Game.player.global_position)
	check(ended < started - 0.5, "he closed on you (%.2f to %.2f)" % [started, ended])
