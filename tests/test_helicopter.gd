extends "res://tests/test_case.gd"
## The way off the roof: the helicopter arrives when the Director is dead, and climbing into
## it is what ends the run.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func _pad() -> Helipad:
	return get_tree().get_first_node_in_group(&"exit") as Helipad


func test_the_pad_calls_a_helicopter_when_the_roof_is_clear() -> void:
	check(Game.load_level("roof"), "roof loads")
	var pad: Helipad = _pad()
	check(pad != null, "the roof exit is a helipad")
	check(pad.helicopter == null, "nothing is flying while they are alive")
	pad.unlock()
	check(pad.helicopter != null, "one is called the moment the floor is clear")
	check(not pad.helicopter.has_landed, "it starts out on its way in")
	# It comes in from well off the side of the building.
	check(pad.helicopter.global_position.y > 10.0, "it starts in the air")


func test_it_lands_beside_the_pad_not_on_it() -> void:
	check(Game.load_level("roof"), "roof loads")
	var pad: Helipad = _pad()
	pad.unlock()
	var heli: Helicopter = pad.helicopter
	heli._touch_down()
	heli.global_position = pad.global_position + Helicopter.PARKED
	check(heli.has_landed, "it is down")
	var flat: Vector2 = Vector2(heli.global_position.x - pad.global_position.x,
		heli.global_position.z - pad.global_position.z)
	check(flat.length() > 2.0, "it parks clear of the pad, so the pad can be stood on")
	check(flat.length() < 5.0, "but within a step of it")


func test_stepping_on_the_pad_early_does_nothing() -> void:
	check(Game.load_level("roof"), "roof loads")
	var pad: Helipad = _pad()
	pad.unlock()
	pad._on_body_entered(Game.player)
	check(not Game.player.riding, "he waits: it has not touched down yet")
	check_eq(Game.level_name, "roof", "and he is still on the roof")


func test_climbing_in_freezes_him_and_ends_the_run() -> void:
	check(Game.load_level("roof"), "roof loads")
	var pad: Helipad = _pad()
	pad.unlock()
	var heli: Helicopter = pad.helicopter
	heli.global_position = pad.global_position + Helicopter.PARKED
	heli._touch_down()
	heli.board(Game.player)
	check(Game.player.riding, "he is on the ladder, not walking")
	check(not Game.player.input_enabled, "and he has no say in it")
	# The rest of it is one chain of tweens; the last link is what ends the run.
	heli._finish()
	check(not Game.player.riding, "he is let go at the end")
	check_eq(Game.state, Game.State.ENDING, "the run is over")


func test_the_pilot_says_where_they_are_going() -> void:
	check(Game.load_level("roof"), "roof loads")
	var pad: Helipad = _pad()
	pad.unlock()
	var heli: Helicopter = pad.helicopter
	heli._say_the_line()
	check(heli._bubble.visible, "the pilot speaks up")
	check("SPACE STATION" in heli._bubble.text, "and says where next: %s" % heli._bubble.text)
