extends "res://tests/test_case.gd"
## The cleaner mops up after the player, counts, and on the fifth spill comes for him.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = false
	Game.start_run_state_for_tests()
	check(Game.load_floor(5), "cafeteria loads")      # buckets and mugs both
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _spill(at: Vector3) -> Puddle:
	var pool := Puddle.new()
	pool.radius = T.spill_radius
	pool.life = T.spill_seconds
	Game.entities_root(self).add_child(pool)
	pool.global_position = Vector3(at.x, 0, at.z)
	Game.report_spill(pool)
	return pool


func _out_of_the_lift() -> Vector3:
	var lift: Transform3D = LevelBuilder.elevator_transform(Game.data, Game.data.player_start)
	return Game.data.cell_center(Game.data.front_cell(Game.data.player_start), 0.05) - lift.basis.z * 2.5


func test_every_floor_with_a_bucket_or_a_mug_has_a_cleaner_on_call() -> void:
	var with: int = 0
	for i: int in Game.FLOORS.size():
		var d: LevelData = LevelParser.load_level(Game.FLOORS[i])
		var spillable: bool = d.pickups.any(func(e: Dictionary) -> bool: return e["kind"] == &"bucket" or e["kind"] == &"mug")
		Game.data = d
		check_eq(Game.floor_has_a_cleaner(), spillable, "%s: cleaner exactly when there is something to spill" % Game.FLOORS[i])
		with += 1 if spillable else 0
	check(with >= 10, "and that is a good many floors, got %d" % with)
	Game.data = LevelParser.load_level(Game.FLOORS[5])


func test_nobody_comes_until_something_is_spilled() -> void:
	await wait_physics(30)
	check(Game.cleaner == null, "no cleaner standing about")
	check_eq(get_tree().get_nodes_in_group(&"cleaners").size(), 0, "none in the level")


func test_he_comes_mops_it_up_leaves_a_sign_and_goes() -> void:
	var pool: Puddle = _spill(_out_of_the_lift())
	var man: Cleaner = Game.cleaner
	check(man != null and man.alive, "he is on his way")
	check(not man.is_in_group(&"enemies") and not man.hostile, "and he is nobody's enemy")
	check_eq(man.skin.material, Mats.overalls(), "in overalls")
	check_eq(man.voice.last_line, HelperVoice.line(&"cleaner_1"), "with something to say about it")
	var enemies_before: int = Game.alive_enemies
	for i: int in 900:
		await wait_physics(1)
		if not is_instance_valid(pool):
			break
	check(not is_instance_valid(pool), "the spill is gone")
	check_eq(get_tree().get_nodes_in_group(&"wet_floor_signs").size(), 1, "a wet floor sign stands where it was")
	check_eq(Game.alive_enemies, enemies_before, "he never counted as an enemy")
	for i: int in 900:
		await wait_physics(1)
		if not is_instance_valid(man):
			break
	check(not is_instance_valid(man), "and he has gone back the way he came")
	check(Game.player.alive, "the player is fine")


func test_a_smashed_mug_is_a_spill_too() -> void:
	var mug: Throwable = Throwable.create(&"mug")
	Game.entities_root(self).add_child(mug)
	mug.global_position = _out_of_the_lift() + Vector3(0, 1.0, 0)
	mug.shatter()
	await wait_physics(2)
	check_eq(Game.spills_this_floor, 1, "coffee on the floor counts")
	var coffee: Array = get_tree().get_nodes_in_group(&"puddles").filter(func(p: Puddle) -> bool: return p.coffee)
	check_eq(coffee.size(), 1, "and there it is")
	check(Game.cleaner != null, "and here he comes")


func test_the_fifth_spill_is_one_too_many() -> void:
	var at: Vector3 = _out_of_the_lift()
	for i: int in T.cleaner_strikes - 1:
		_spill(at + Vector3(0.3 * i, 0, 0))
	var man: Cleaner = Game.cleaner
	check(not man.hostile, "four spills and he is only muttering")
	check_eq(man.voice.last_line, HelperVoice.line(&"cleaner_4"), "one more, I dare you")
	var snapped: Dictionary = {"yes": false}
	man.snapped.connect(func() -> void: snapped["yes"] = true)
	_spill(at + Vector3(0, 0, 1))
	check(snapped["yes"] and man.hostile, "the fifth does it")
	check_eq(man.voice.last_line, HelperVoice.line(&"cleaner_snap"), "and he says so")
	Game.player.global_position = man.global_position - man.global_transform.basis.z * 1.2 + Vector3(0, 0.05, 0)
	for i: int in 240:
		await wait_physics(1)
		if not Game.player.alive:
			break
	check(not Game.player.alive, "a broom across the head is a broom across the head")


func test_he_can_be_outrun_and_he_can_be_killed() -> void:
	check(T.cleaner_chase_speed < T.walk_speed, "slower than the player")
	_spill(_out_of_the_lift())
	var man: Cleaner = Game.cleaner
	man.on_bullet_hit(null, man.global_position, Vector3.BACK)
	await wait_physics(2)
	check(not is_instance_valid(man) or not man.alive, "one bullet")
	_spill(_out_of_the_lift() + Vector3(1, 0, 0))
	await wait_physics(2)
	check_eq(get_tree().get_nodes_in_group(&"cleaners").size(), 0, "and nobody replaces him on this floor")


func test_a_new_floor_forgets_the_count() -> void:
	for i: int in 3:
		_spill(_out_of_the_lift() + Vector3(0.3 * i, 0, 0))
	check_eq(Game.spills_this_floor, 3, "three so far")
	check(Game.load_floor(5), "the floor again")
	await wait_physics(2)
	check_eq(Game.spills_this_floor, 0, "a clean slate")
	check(Game.cleaner == null, "and no cleaner out")
