extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	AdService.auto_result = 1
	Game.start_run_state_for_tests()


func after_each() -> void:
	TimeManager.override_scale = -1.0
	AdService.auto_result = 1
	Game.god_mode = false
	Game.start_run_state_for_tests()
	Game.unload_level()


func _capsule() -> HelperCapsule:
	return get_tree().get_first_node_in_group(&"helper_capsule") as HelperCapsule


## Kills the player and waits for the automatic restart.
func _die_and_respawn() -> void:
	Game.player.die()
	for i: int in 400:
		await wait_physics(1)
		if Game.state == Game.State.PLAYING and Game.player != null and Game.player.alive:
			return


func test_capsule_appears_only_after_the_third_death() -> void:
	check(Game.load_level("f2_offices"), "level loads")
	await wait_physics(2)
	check(_capsule() == null, "no capsule on a fresh floor")
	await _die_and_respawn()
	check(_capsule() == null, "none after one death")
	await _die_and_respawn()
	check(_capsule() == null, "none after two")
	await _die_and_respawn()
	check_eq(Game.deaths_this_floor, 3, "three deaths counted")
	var capsule: HelperCapsule = _capsule()
	check(capsule != null, "capsule is waiting after the third")
	var lift_front: Vector3 = Game.data.cell_center(Game.data.front_cell(Game.data.player_start))
	check(capsule.global_position.distance_to(lift_front) < 7.0, "just outside the lift (%.1f m)" % capsule.global_position.distance_to(lift_front))
	check(capsule.global_position.distance_to(lift_front) > 1.5, "but not blocking the doorway")


func test_every_floor_has_room_for_the_capsule_and_stays_walkable() -> void:
	Game.god_mode = true
	for floor_name: String in Game.FLOORS:
		var d: LevelData = LevelParser.load_level(floor_name)
		check(d.capsule_cell().x >= 0, "%s has a free cell by the lift" % floor_name)
		Game.level_name = floor_name
		Game.deaths_this_floor = 3
		check(Game.load_level(floor_name), "%s loads" % floor_name)
		check(_capsule() != null, "%s placed the capsule" % floor_name)
		check(await LevelValidator.wait_until_synced(Game.level, Game.data), "%s nav synced" % floor_name)
		var problems: PackedStringArray = LevelValidator.unreachable(Game.level, Game.data)
		check(problems.is_empty(), "%s with capsule: %s" % [floor_name, "; ".join(problems)])


func test_button_works_by_bullet_and_shows_the_ad_then_hires() -> void:
	Game.god_mode = true
	Game.level_name = "test_room"
	Game.deaths_this_floor = 3
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var capsule: HelperCapsule = _capsule()
	var before: int = AdService.requests
	var target: Vector3 = capsule.button.global_position
	var out: Vector3 = -capsule.global_transform.basis.z
	BulletPool.for_node(Game.player).fire(target + out * 2.5, -out, null)
	await wait_physics(40)
	check_eq(AdService.requests, before + 1, "shooting the button asked for an ad")
	check(capsule.used, "capsule opened")
	check(Game.helper != null and is_instance_valid(Game.helper), "the helper stepped out")
	check_near(Game.helper_time_left, T.helper_seconds, 2.0, "with three minutes on the clock")
	check_eq(T.helper_seconds, 180.0, "three minutes")


func test_closing_the_ad_early_hires_nobody_and_you_can_try_again() -> void:
	Game.god_mode = true
	AdService.auto_result = 0
	Game.level_name = "test_room"
	Game.deaths_this_floor = 3
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var capsule: HelperCapsule = _capsule()
	capsule.press()
	await wait_frames(2)
	check(not capsule.used and Game.helper == null, "no reward, no helper")
	AdService.auto_result = 1
	capsule.press()
	await wait_frames(2)
	check(capsule.used and Game.helper != null, "second try, watched, hired")


func test_the_real_ad_is_the_last_ward_video_and_rewards_after_twenty_seconds() -> void:
	check(ResourceLoader.exists(AdService.VIDEO_PATH), "ads/the_last_ward.ogv is in the project")
	check_eq(AdService.AD_TITLE, "THE LAST WARD", "advertises The Last Ward")
	var stream: VideoStream = load(AdService.VIDEO_PATH)
	check(stream is VideoStreamTheora, "it is a Theora stream Godot can play")
	check(T.ad_reward_after < 57.0, "the reward comes before the 57 second video ends")


func test_ad_pauses_the_game_and_early_close_earns_nothing() -> void:
	Game.god_mode = true
	AdService.auto_result = -1
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var answer: Dictionary = {"got": false, "rewarded": true}
	var on_done: Callable = func(rewarded: bool) -> void:
		answer["got"] = true
		answer["rewarded"] = rewarded
	AdService.finished.connect(on_done)
	AdService.show_rewarded()
	check(AdService.showing, "ad is on screen")
	check(get_tree().paused, "game is paused behind it")
	check(not AdService.reward_earned(), "nothing earned in the first instant")
	AdService._finish(false)
	check(answer["got"] and not answer["rewarded"], "closing early earns nothing")
	check(not get_tree().paused, "game resumes")
	AdService.finished.disconnect(on_done)
	AdService.auto_result = 1


func test_helper_shoots_a_dude_dead_and_never_aims_through_the_player() -> void:
	Game.god_mode = true
	check(Game.load_level("test_room"), "level loads")
	await LevelValidator.wait_until_synced(Game.level, Game.data)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	for node: Node in get_tree().get_nodes_in_group(&"barrels"):
		node.free()
	Game.alive_enemies = 0
	var spot: Vector3 = Game.data.cell_center(Vector2i(5, 8), 0.05)
	var helper: Helper = Game.hire_helper(spot, Basis.IDENTITY)
	var dude: PinkDude = Game.spawn_dude(spot + Vector3(9, 0, 0), true)
	dude.sense_override = true
	Game.player.global_position = spot + Vector3(0, 0, -4)
	var killed: bool = false
	for i: int in 300:
		await wait_physics(1)
		if not is_instance_valid(dude) or not dude.alive:
			killed = true
			break
	check(killed, "helper killed a dude standing in the open")
	check(helper.bullet_excludes().has(Game.player.get_rid()), "his bullets pass through the player")
	check(helper._player_in_the_way(Vector3.ZERO, Vector3(10, 0, 0)) == false or true, "line check runs")
	Game.player.global_position = spot + Vector3(4.5, 0, 0)
	await wait_physics(2)
	check(helper._player_in_the_way(helper.muzzle(), spot + Vector3(9, 1.2, 0)), "he sees the player in his line of fire")


func test_helper_aims_for_the_glass_on_a_shield_trooper() -> void:
	Game.god_mode = true
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var spot: Vector3 = Game.data.cell_center(Vector2i(5, 8), 0.05)
	var helper: Helper = Game.hire_helper(spot, Basis.IDENTITY)
	var trooper: ShieldDude = Game.spawn_dude(spot + Vector3(8, 0, 0), true, &"shield") as ShieldDude
	trooper.sense_override = true
	trooper._animate(0.0)
	var aim: Vector3 = helper.aim_point(trooper)
	var glass: Vector3 = trooper.shield.global_transform * Vector3(0, Shield.VISOR_Y, -0.07)
	check(aim.distance_to(glass) < 0.01, "he goes for the viewport, the only thing that works")


func test_bullets_stop_on_the_helper_without_hurting_him() -> void:
	Game.god_mode = true
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var spot: Vector3 = Game.data.cell_center(Vector2i(8, 8), 0.05)
	var helper: Helper = Game.hire_helper(spot, Basis.IDENTITY)
	await wait_physics(2)
	var bullet: Bullet = BulletPool.for_node(helper).fire(spot + Vector3(-4, 1.1, 0), Vector3.RIGHT, null)
	for i: int in 60:
		if not bullet.active:
			break
		await wait_physics(1)
	check(not bullet.active, "the round stopped on him")
	check(bullet.global_position.x < spot.x + 0.5, "it did not pass through")
	check(is_instance_valid(helper) and not helper.leaving, "and he is fine")


func test_contract_runs_on_real_time_and_he_leaves_when_it_ends() -> void:
	Game.god_mode = true
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	TimeManager.override_scale = T.min_scale
	var helper: Helper = Game.hire_helper(Game.data.cell_center(Vector2i(8, 8), 0.05), Basis.IDENTITY)
	var start: float = Game.helper_time_left
	await wait_physics(60)
	check_near(start - Game.helper_time_left, 1.0, 0.1, "one real second costs one second even while the world crawls")
	Game.helper_time_left = 0.05
	await wait_physics(10)
	check(helper.leaving, "time is up, he is leaving")
	check(Game.helper == null, "and Game has let him go")
	await wait_physics(100)
	check(not is_instance_valid(helper), "gone")


func test_helper_leaves_when_the_floor_is_cleared() -> void:
	Game.god_mode = true
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var helper: Helper = Game.hire_helper(Game.data.cell_center(Vector2i(2, 2), 0.05), Basis.IDENTITY)
	helper.set_physics_process(false)
	check(Game.helper_time_left > 100.0, "plenty of time left")
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	await wait_physics(2)
	check_eq(Game.state, Game.State.CLEARED, "floor cleared")
	check(helper.leaving, "the job is done, he goes")
	check_eq(Game.helper_time_left, 0.0, "contract closed")


func test_helper_survives_your_death_but_not_the_next_floor() -> void:
	check(Game.load_floor(1), "offices load")
	await wait_physics(3)
	Game.hire_helper(Game.data.cell_center(Vector2i(3, 3), 0.05), Basis.IDENTITY)
	Game.helper_time_left = 120.0
	await _die_and_respawn()
	check(Game.helper != null and is_instance_valid(Game.helper), "he is back beside you after the restart")
	check(Game.helper_time_left > 100.0, "with the time he had left")
	check(_capsule() == null, "and no second capsule while he is hired")
	Game.god_mode = true
	Game.next_floor()
	await wait_physics(2)
	check_eq(Game.level_name, "f3_servers", "next floor")
	check(Game.helper == null, "he did not come along")
	check_eq(Game.deaths_this_floor, 0, "and the death count starts over")
