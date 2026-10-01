extends "res://tests/test_case.gd"
## A shoved dude comes back down and lives. He sank through the world once.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_a_shoved_dude_lands_and_lives() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(3.0, 0.0, 0.0)
	await wait_physics(2)
	dude.sense_override = true
	# The flight runs on world time, and a standing player means world time barely moves.
	TimeManager.override_scale = 1.0
	var started: float = dude.global_position.y
	dude.shove(Vector3(2.0, 2.0, 0.0))
	for step: int in 240:
		await wait_physics(1)
		if not dude.flung:
			break
	check(is_instance_valid(dude), "he is still here")
	check(not dude.flung, "he came down")
	check(dude.alive, "and he is alive")
	check(dude.global_position.y > started - 0.2, "he did not sink (%.2f against %.2f)" % [dude.global_position.y, started])
	TimeManager.override_scale = -1.0
	dude.queue_free()


func test_nobody_dies_of_a_fall_they_did_not_take() -> void:
	check(Game.load_level("f11_sewers"), "a floor with windows loads")
	await wait_physics(3)
	var before: int = Game.alive_enemies
	# Nobody touches anything for a few seconds of real time.
	for step: int in 180:
		await wait_physics(1)
	check_eq(Game.alive_enemies, before, "the floor does not kill its own")
