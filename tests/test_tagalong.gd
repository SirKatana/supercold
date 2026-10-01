extends "res://tests/test_case.gd"
## Standing in the lift when a member of staff takes it.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.back_to = ""


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.back_to = ""
	Game.unload_level()


func test_standing_with_the_cleaner_when_he_leaves_takes_you_with_him() -> void:
	check(Game.load_level("f6_cafeteria"), "a floor with a cleaner loads")
	await wait_physics(3)
	var mop := Cleaner.new()
	Game.entities_root(self).add_child(mop)
	await wait_physics(2)
	# He is at the lift and so are you.
	mop.report_for_duty(Game.player.global_position)
	mop.mode = Cleaner.Mode.LEAVING
	for step: int in 120:
		await wait_physics(1)
		if Game.level_name != "f6_cafeteria":
			break
	check_eq(Game.level_name, "lair_cleaners", "down you go with him")
	check_eq(Game.back_to, "f6_cafeteria", "and it knows where you came from")


func test_standing_well_clear_of_him_does_not() -> void:
	check(Game.load_level("f6_cafeteria"), "floor loads")
	await wait_physics(3)
	var mop := Cleaner.new()
	Game.entities_root(self).add_child(mop)
	# Posted well clear of the player and sent home in the same breath: he reaches the lift on
	# the first step, which is the point.
	mop.report_for_duty(Game.player.global_position + Vector3(6, 0, 0))
	mop.mode = Cleaner.Mode.LEAVING
	for step: int in 120:
		await wait_physics(1)
		if not is_instance_valid(mop):
			break
	check(not is_instance_valid(mop), "he has gone")
	check_eq(Game.level_name, "f6_cafeteria", "and left you where you were")
