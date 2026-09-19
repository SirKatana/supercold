extends "res://tests/test_case.gd"


func after_each() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	TimeManager.override_scale = -1.0
	Game.unload_level()


func test_target_is_min_when_idle() -> void:
	check_near(TimeManager.compute_target(0.0, 0.0, false, T), T.min_scale, 0.0001, "idle target")


func test_target_is_one_at_walk_speed() -> void:
	check_near(TimeManager.compute_target(T.walk_speed, 0.0, false, T), 1.0, 0.0001, "walking target")
	check_near(TimeManager.compute_target(T.walk_speed * 3.0, 0.0, false, T), 1.0, 0.0001, "clamped above walk speed")


func test_look_is_capped_by_weight() -> void:
	check_near(TimeManager.compute_target(0.0, 9999.0, false, T), T.look_weight, 0.0001, "fast look")
	check_near(TimeManager.compute_target(0.0, T.look_full_deg_per_sec * 0.5, false, T), T.look_weight * 0.5, 0.0001, "half look")


func test_burst_forces_full_speed() -> void:
	check_near(TimeManager.compute_target(0.0, 0.0, true, T), 1.0, 0.0001, "burst target")


func test_rise_is_faster_than_fall() -> void:
	var up: float = TimeManager.step_scale(0.5, 1.0, 0.01, T) - 0.5
	var down: float = 0.5 - TimeManager.step_scale(0.5, T.min_scale, 0.01, T)
	check_near(up, T.scale_rise_rate * 0.01, 0.0001, "rise step")
	check_near(down, T.scale_fall_rate * 0.01, 0.0001, "fall step")
	check(up > down, "rise should outpace fall")


func test_never_below_min_or_above_one() -> void:
	check_near(TimeManager.step_scale(T.min_scale, 0.0, 1.0, T), T.min_scale, 0.0001, "floor clamp")
	check_near(TimeManager.step_scale(0.99, 5.0, 1.0, T), 1.0, 0.0001, "ceiling clamp")
	check(T.min_scale > 0.0, "min scale must never freeze the world")


func test_world_delta_scales() -> void:
	TimeManager.override_scale = 0.25
	await wait_frames(2)
	check_near(TimeManager.world_delta(0.1), 0.025, 0.0001, "world delta")


func test_standing_still_settles_to_min_and_walking_reaches_one() -> void:
	check(Game.load_level("test_room"), "test room should load")
	await wait_physics(90)
	check_near(TimeManager.world_scale, T.min_scale, 0.001, "standing still")
	var start: Vector3 = Game.player.global_position
	Input.action_press(&"move_forward")
	await wait_physics(40)
	check_near(TimeManager.world_scale, 1.0, 0.001, "walking")
	check(Game.player.global_position.distance_to(start) > 1.5, "player should have moved at real speed")
	Input.action_release(&"move_forward")
	await wait_physics(90)
	check_near(TimeManager.world_scale, T.min_scale, 0.001, "settles again after stopping")
