extends "res://tests/test_case.gd"
## The station: a fraction of a g, stars behind the glass, and the men standing on the rocks
## who never come down to you.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_the_tower_pulls_harder_than_the_station() -> void:
	check(Game.load_level("f5_executive"), "a tower floor loads")
	check_eq(Game.gravity_scale, 1.0, "a full g downstairs")
	check(Game.load_level("f31_airlock"), "a station floor loads")
	check_eq(Game.gravity_scale, Game.SPACE_GRAVITY, "and a fraction of one up here")
	check(Game.SPACE_GRAVITY < 0.6, "enough to feel it in a jump")


func test_a_station_floor_says_it_is_in_space() -> void:
	for floor_name: String in ["f31_airlock", "f36_reactor", "f40_bridge"]:
		var d: LevelData = LevelParser.load_level(floor_name)
		check(d.in_space, "%s is on the station" % floor_name)
	check(not LevelParser.load_level("f5_executive").in_space, "the tower is not")


func test_open_station_floors_hang_rocks_with_men_on_them() -> void:
	check(Game.load_level("f40_bridge"), "an open station floor loads")
	await wait_physics(3)
	var rocks: Array[Node] = []
	var flyers: Array[Node] = []
	for node: Node in Game.entities_root(self).get_children():
		if node is Planetoid:
			rocks.append(node)
		elif node is Orbiter:
			flyers.append(node)
	check(rocks.size() >= 2, "rocks are up there (%d)" % rocks.size())
	check(flyers.size() >= 1, "and somebody is standing on them (%d)" % flyers.size())
	for rock: Node in rocks:
		check((rock as Planetoid).global_position.y > 6.0, "well out of reach")
	for flyer: Node in flyers:
		check((flyer as Orbiter).global_position.y > 6.0, "so is he")
		check((flyer as Orbiter).has_weapon(), "and he is armed")


func test_the_tower_has_no_rocks_in_it() -> void:
	check(Game.load_level("f5_executive"), "a tower floor loads")
	await wait_physics(2)
	for node: Node in Game.entities_root(self).get_children():
		check(not (node is Planetoid), "no rocks indoors")
		check(not (node is Orbiter), "and nobody flying about in the office")


func test_he_hops_between_rocks_and_never_touches_the_floor() -> void:
	check(Game.load_level("f40_bridge"), "floor loads")
	await wait_physics(3)
	var flyer: Orbiter = null
	for node: Node in Game.entities_root(self).get_children():
		if node is Orbiter:
			flyer = node
			break
	check(flyer != null, "somebody is up there")
	flyer.hop_after = 0.05
	flyer.hop_seconds = 0.4
	var started: Vector3 = flyer.global_position
	var lowest: float = flyer.global_position.y
	for step: int in 180:
		await wait_physics(1)
		lowest = minf(lowest, flyer.global_position.y)
	check(flyer.global_position.distance_to(started) > 2.0, "he moved to another rock")
	check(lowest > 5.0, "and never came down (lowest %.1f m)" % lowest)


func test_a_bullet_still_takes_him_off_his_rock() -> void:
	check(Game.load_level("f40_bridge"), "floor loads")
	await wait_physics(3)
	var flyer: Orbiter = null
	for node: Node in Game.entities_root(self).get_children():
		if node is Orbiter:
			flyer = node
			break
	check(flyer != null, "somebody is up there")
	var before: int = Game.alive_enemies
	flyer.on_bullet_hit(null, flyer.global_position + Vector3.UP, Vector3.LEFT)
	check(not flyer.alive, "one round is enough, same as anyone else")
	check_eq(Game.alive_enemies, before - 1, "and the floor count knows")


func test_low_gravity_does_not_turn_a_jump_into_a_leap_onto_the_furniture() -> void:
	# Apex height is velocity squared over twice the pull. Cutting the push by the square root
	# of the pull keeps that number where it is in the tower: floatier, not higher.
	Game.gravity_scale = 1.0
	var tower: float = pow(T.jump_velocity * Game.jump_scale(), 2.0) / (2.0 * T.gravity * Game.gravity_scale)
	Game.gravity_scale = Game.SPACE_GRAVITY
	var station: float = pow(T.jump_velocity * Game.jump_scale(), 2.0) / (2.0 * T.gravity * Game.gravity_scale)
	Game.gravity_scale = 1.0
	check(absf(station - tower) < 0.02, "same height up there: %.2f m against %.2f m" % [station, tower])
	check(tower < 1.1, "and neither of them clears a desk (%.2f m)" % tower)
