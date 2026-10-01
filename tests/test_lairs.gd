extends "res://tests/test_case.gd"
## Getting into a lift with one of the staff, and what is at the bottom of it.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.back_to = ""


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.back_to = ""
	Game.unload_level()


func test_both_staff_rooms_exist_and_know_what_they_are() -> void:
	for id: StringName in Game.LAIRS:
		var room: LevelData = LevelParser.load_level(Game.LAIRS[id])
		check(room.errors.is_empty(), "%s parses: %s" % [Game.LAIRS[id], ", ".join(room.errors)])
		check(room.lair, "%s knows it is a staff room" % Game.LAIRS[id])
		check(room.player_start.x >= 0, "with somewhere to put you")


func test_riding_down_with_a_cleaner_fills_the_room_with_them() -> void:
	check(Game.load_level("f6_cafeteria"), "a floor with a cleaner loads")
	await wait_physics(3)
	Game.take_me_to_the_lair(&"cleaner")
	await wait_physics(6)
	check_eq(Game.level_name, "lair_cleaners", "down to the cleaners' room")
	check_eq(Game.back_to, "f6_cafeteria", "and it remembers where you came from")
	var mops: int = get_tree().get_nodes_in_group(&"cleaners").size()
	check(mops >= T.lair_cleaners, "and they are all in (%d)" % mops)
	var angry: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"cleaners"):
		if (node as Cleaner).hostile:
			angry += 1
	check(angry >= T.lair_cleaners, "all of them want a word (%d)" % angry)


func test_riding_down_with_security_fills_it_with_guards() -> void:
	check(Game.load_level("f2_offices"), "a floor loads")
	await wait_physics(3)
	Game.take_me_to_the_lair(&"security")
	await wait_physics(6)
	check_eq(Game.level_name, "lair_security", "down to security")
	check(get_tree().get_nodes_in_group(&"security").size() >= T.lair_guards,
		"twenty of them (%d)" % get_tree().get_nodes_in_group(&"security").size())


func test_dying_down_there_puts_you_back_where_you_got_in() -> void:
	check(Game.load_level("f6_cafeteria"), "a floor loads")
	await wait_physics(3)
	Game.take_me_to_the_lair(&"cleaner")
	await wait_physics(6)
	check(Game.in_a_lair(), "you are in the staff room")
	Game.restart_floor()
	await wait_physics(4)
	check_eq(Game.level_name, "f6_cafeteria", "and you wake up on your own floor")
	check_eq(Game.back_to, "", "with the way back forgotten")
