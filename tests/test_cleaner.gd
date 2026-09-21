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


func test_he_can_be_outrun() -> void:
	check(T.cleaner_chase_speed < T.walk_speed, "slower than the player")


func test_shooting_him_only_makes_him_ask_why() -> void:
	_spill(_out_of_the_lift())
	var man: Cleaner = Game.cleaner
	var dude: PinkDude = Game.spawn_dude(man.global_position + Vector3(4, 0, 0), true)
	dude.sense_override = true
	var blamed: Array = []
	man.outraged.connect(func(who: Node3D) -> void: blamed.append(who))
	for i: int in 12:
		var fake := Node.new()
		fake.set_script(load("res://tests/fake_bullet.gd"))
		fake.set(&"shooter", dude)
		man.on_bullet_hit(fake, man.global_position + Vector3(0, 1.2, 0), Vector3.RIGHT)
		fake.free()
	await wait_physics(12)
	check(is_instance_valid(man) and man.alive, "a dozen rounds and he is still standing")
	check(not man.hostile, "and he has not gone for anybody")
	check_eq(blamed.size(), 12, "he noticed every one")
	check(blamed[0] == dude, "and he knows which pink dude it was")
	check_eq(man.voice.last_line, HelperVoice.line(&"cleaner_why"), "WHY!")
	var toward: Vector3 = (dude.global_position - man.global_position).normalized()
	check((-man.global_transform.basis.z).dot(toward) > 0.7, "said to the dude's face")
	check(dude.alive, "the dude is untouched: he shouts, he does not hit")
	check(Game.player.alive, "and so is the player")
	for i: int in 900:
		await wait_physics(1)
		if get_tree().get_nodes_in_group(&"puddles").filter(func(p: Puddle) -> bool: return p.radius > 0.0).is_empty():
			break
	check(get_tree().get_nodes_in_group(&"wet_floor_signs").size() >= 1, "then he gets on with the mopping")


func test_the_player_shooting_him_does_not_start_a_fight_either() -> void:
	_spill(_out_of_the_lift())
	var man: Cleaner = Game.cleaner
	for i: int in 5:
		man.on_punched(Game.player, man.global_position)
		man.on_laser(Vector3.FORWARD)
		man.on_explosion(man.global_position + Vector3(1, 0, 0))
	await wait_physics(5)
	check(man.alive and not man.hostile, "punched, lasered and blown up: alive, and still only a cleaner")


func test_a_new_floor_forgets_the_count() -> void:
	for i: int in 3:
		_spill(_out_of_the_lift() + Vector3(0.3 * i, 0, 0))
	check_eq(Game.spills_this_floor, 3, "three so far")
	check(Game.load_floor(5), "the floor again")
	await wait_physics(2)
	check_eq(Game.spills_this_floor, 0, "a clean slate")
	check(Game.cleaner == null, "and no cleaner out")
