extends "res://tests/test_case.gd"
## The kick, and falling out of the building.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_a_kick_hurts_and_takes_him_off_his_feet() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(2.0, 0, 0)
	await wait_physics(2)
	dude.sense_override = true
	var before: int = dude.hp
	# The boot itself, without relying on where the test room put the player's nose.
	dude.take_kick(Vector3(1, 0, 0))
	check(dude.hp < before, "it hurt him (%d to %d)" % [before, dude.hp])
	check(dude.flung, "and it took him off his feet")
	check(not dude.has_weapon(), "and his gun is on the floor")
	dude.queue_free()


func test_the_kick_has_a_cooldown_on_world_time() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	check(Game.player.hands.kick(), "first one lands")
	check(not Game.player.hands.kick(), "the second has to wait")
	check(Game.player.hands.kick_cooldown_left > 0.0, "there is a cooldown running")


func test_a_punch_still_leaves_him_standing() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(2.0, 0, 0)
	await wait_physics(2)
	dude.sense_override = true
	dude.on_punched(Game.player, dude.global_position)
	check(not dude.flung, "a punch is not a kick")
	dude.queue_free()


func test_going_out_of_the_window_kills_you() -> void:
	check(Game.load_level("f12_kitchen"), "a floor with windows loads")
	await wait_physics(3)
	Game.god_mode = false
	var d: LevelData = Game.data
	var pane: GlassPane = get_tree().get_first_node_in_group(&"windows") as GlassPane
	var here: Vector2i = d.cell_of(pane.global_position)
	var air := Vector2i.ZERO
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if d.char_at(here + step) == " " or d.char_at(here + step) == "":
			air = step
	check(air != Vector2i.ZERO, "there is air on the other side of the glass")
	Game.player.global_position = d.cell_center(here + air, 0.2)
	await wait_physics(3)
	check(not Game.player.alive, "out there, you fall, and that is that")


func test_no_window_floor_has_no_holes_in_it() -> void:
	# The carve must never open a trench through the middle of a floor.
	for floor_name: String in ["f10_vault", "f11_sewers", "f12_kitchen", "f14_glassworks", "f15_restrooms"]:
		var d: LevelData = LevelParser.load_level(floor_name)
		for y: int in d.height:
			for x: int in d.width:
				if d.rows[y][x] != " ":
					continue
				# Every void cell must be outside: no floor next to it.
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var beside: String = d.char_at(Vector2i(x, y) + step)
					check(beside != "." and beside != "~" and beside != "i",
						"%s: void at %d,%d is right beside a room" % [floor_name, x, y])
