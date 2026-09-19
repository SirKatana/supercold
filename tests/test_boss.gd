extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()



func _find_director() -> Director:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if node is Director:
			return node as Director
	return null


func test_roof_has_a_director() -> void:
	check(Game.load_level("roof"), "roof loads")
	await wait_physics(2)
	var boss: Director = _find_director()
	check(boss != null, "director spawned")
	check_near(boss.body_scale, T.director_scale, 0.001, "director is bigger")
	check(boss.off_hand_weapon != null, "carries a second pistol")
	check(Game.data.open_sky, "roof has no ceiling")


func test_director_takes_exactly_three_bullets_and_calls_waves() -> void:
	check(Game.load_level("roof"), "roof loads")
	await wait_physics(2)
	var boss: Director = _find_director()
	var before: int = Game.alive_enemies
	boss.on_bullet_hit(null, boss.global_position, Vector3.UP)
	check(boss.alive, "alive after one bullet")
	check_eq(boss.state_name, &"stunned", "flinches")
	check_eq(Game.alive_enemies, before + T.director_wave_size, "first wave arrived")
	boss.on_bullet_hit(null, boss.global_position, Vector3.UP)
	check(boss.alive, "alive after two bullets")
	check_eq(Game.alive_enemies, before + T.director_wave_size * 2, "second wave arrived")
	boss.on_bullet_hit(null, boss.global_position, Vector3.UP)
	check(not boss.alive, "third bullet kills")
	check_eq(Game.alive_enemies, before + T.director_wave_size * 2 - 1, "no wave on the killing shot")


func test_director_shrugs_off_blunt_hits() -> void:
	check(Game.load_level("roof"), "roof loads")
	await wait_physics(2)
	var boss: Director = _find_director()
	for i: int in 6:
		boss.on_punched(self, Vector3.ZERO)
	check(boss.alive, "punches do not kill him")
	check(boss.has_weapon(), "and do not disarm him")
	check_eq(boss.bullets_left, T.director_hp, "bullet health untouched")


func test_flinch_recovers_after_tuned_time() -> void:
	check(Game.load_level("roof"), "roof loads")
	await wait_physics(2)
	var boss: Director = _find_director()
	boss.sense_override = true
	boss.set_physics_process(false)
	boss.on_bullet_hit(null, boss.global_position, Vector3.UP)
	var t: float = 0.0
	while t < T.director_flinch - 0.1:
		boss.tick(1.0 / 60.0)
		t += 1.0 / 60.0
	check_eq(boss.state_name, &"stunned", "still flinching")
	for i: int in 12:
		boss.tick(1.0 / 60.0)
	check(boss.state_name != &"stunned", "recovered")


func test_clearing_the_roof_ends_the_run() -> void:
	check(Game.load_level("roof"), "roof loads")
	await wait_physics(3)
	var finished: Dictionary = {"count": 0}
	var on_finished: Callable = func() -> void: finished["count"] += 1
	Game.run_finished.connect(on_finished)
	var pad: Helipad = get_tree().get_first_node_in_group(&"exit") as Helipad
	check(pad != null, "the roof exit is a helipad")
	Game.player.global_position = pad.global_position + Vector3(0, 0.05, 0)
	for guard: int in 8:
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var dude: PinkDude = node as PinkDude
			if dude is Director:
				dude.on_bullet_hit(null, dude.global_position, Vector3.UP)
			elif dude.alive:
				dude.die()
		await wait_physics(2)
		if Game.alive_enemies <= 0:
			break
	await wait_physics(5)
	check_eq(Game.state, Game.State.ENDING, "run ends on the roof")
	check_eq(finished["count"], 1, "run_finished fired once")
	Game.run_finished.disconnect(on_finished)
