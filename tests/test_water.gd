extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()


func after_each() -> void:
	for action: StringName in [&"jump", &"move_forward"]:
		Input.action_release(action)
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _pool() -> DeepWater:
	return get_tree().get_first_node_in_group(&"deep_water") as DeepWater


func test_water_shader_does_the_things_water_does() -> void:
	var code: String = (load("res://fx/water.gdshader") as Shader).code
	for needed: String in ["hint_screen_texture", "hint_depth_texture", "global uniform float world_time",
			"refraction", "foam_width", "fresnel", "caustics", "deep_color", "shallow_color", "RENDERER_COMPATIBILITY"]:
		check(code.contains(needed), "water shader is missing '%s'" % needed)
	check(Mats.water() is ShaderMaterial and Mats.water_deep() is ShaderMaterial, "both waters use it")
	check_eq(Mats.water().get_shader_parameter(&"foam_width"), 0.0, "a film of water on the floor has no foam")


func test_water_runs_on_world_time() -> void:
	TimeManager.override_scale = 1.0
	await wait_frames(2)
	var start: float = TimeManager.world_time
	await wait_frames(30)
	var fast: float = TimeManager.world_time - start
	TimeManager.override_scale = T.min_scale
	await wait_frames(2)
	start = TimeManager.world_time
	await wait_frames(30)
	var slow: float = TimeManager.world_time - start
	check(fast > 0.4, "it moves at full speed (%.2f)" % fast)
	check(slow < fast * 0.12, "and crawls when the world does (%.3f)" % slow)


func test_level_nine_has_a_real_basin() -> void:
	check(Game.load_level("f9_pool"), "pool level loads")
	await wait_physics(3)
	check(Game.data.deep_cells.size() >= 120, "a big pool (%d cells)" % Game.data.deep_cells.size())
	var pool: DeepWater = _pool()
	check(pool != null, "with water in it")
	var space: PhysicsDirectSpaceState3D = Game.level.get_world_3d().direct_space_state
	var over_pool: Vector3 = pool.global_position
	var down := PhysicsRayQueryParameters3D.create(over_pool + Vector3.UP * 2.0, over_pool + Vector3.DOWN * 6.0, 1)
	var hit: Dictionary = space.intersect_ray(down)
	check(not hit.is_empty(), "there is a bottom")
	check_near((hit["position"] as Vector3).y, -T.pool_depth, 0.05, "and it is %.1f m down" % T.pool_depth)
	var deck: Vector3 = Game.data.cell_center(Vector2i(5, 12))
	var deck_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(deck + Vector3.UP * 2.0, deck + Vector3.DOWN * 6.0, 1))
	check_near((deck_hit["position"] as Vector3).y, 0.0, 0.02, "the deck round it is still at floor level")


func test_player_falls_in_sinks_swims_up_and_climbs_out() -> void:
	check(Game.load_level("f9_pool"), "pool level loads")
	await wait_physics(3)
	var pool: DeepWater = _pool()
	var player: Player = Game.player
	# Drop in near the west wall of the pool, facing that wall.
	var edge_x: float = pool.global_position.x - pool.rect.size.x * pool.cell_size * 0.5
	player.global_position = Vector3(edge_x + 1.0, 0.3, pool.global_position.z)
	player.look_at(player.global_position + Vector3(-5, 0, 0))
	await wait_physics(90)
	check(player.swimming(), "in the water")
	check(player.global_position.y < -0.9, "and sinking (y=%.2f)" % player.global_position.y)
	check(player.head_under_water(), "head under")
	var lowest: float = player.global_position.y
	Input.action_press(&"jump")
	await wait_physics(40)
	check(player.global_position.y > lowest + 0.4, "holding jump swims up")
	Input.action_press(&"move_forward")
	for i: int in 240:
		await wait_physics(1)
		if player.is_on_floor() and player.global_position.y > -0.1:
			break
	check(player.global_position.y > -0.1, "hauled himself out onto the deck (y=%.2f)" % player.global_position.y)
	check(not player.swimming(), "dry land")


func test_dude_who_goes_in_the_pool_drowns() -> void:
	check(Game.load_level("f9_pool"), "pool level loads")
	await wait_physics(3)
	var pool: DeepWater = _pool()
	var dude: PinkDude = Game.spawn_dude(pool.global_position + Vector3(0, 0.2, 0), true)
	dude.sense_override = true
	var before: int = Game.kills
	for i: int in 200:
		await wait_physics(1)
		if not is_instance_valid(dude) or not dude.alive:
			break
	check(not is_instance_valid(dude) or not dude.alive, "pink dudes cannot swim")
	check_eq(Game.kills, before + 1, "and it counts as a kill")
	check(Sfx.history.has(&"splash"), "with a splash")


func test_dudes_never_path_across_the_pool() -> void:
	check(Game.load_level("f9_pool"), "pool level loads")
	check(await LevelValidator.wait_until_synced(Game.level, Game.data), "nav synced")
	var pool: DeepWater = _pool()
	var map: RID = (Game.level.get_node(^"Nav") as NavigationRegion3D).get_navigation_map()
	var half: float = pool.rect.size.x * pool.cell_size * 0.5 + 2.0
	var a: Vector3 = pool.global_position + Vector3(-half, 0, 0)
	var b: Vector3 = pool.global_position + Vector3(half, 0, 0)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, a, b, true)
	check(path.size() >= 2, "there is a way round")
	var over_water: int = 0
	for point: Vector3 in path:
		if absf(point.x - pool.global_position.x) < half - 2.5 and absf(point.z - pool.global_position.z) < pool.rect.size.y * pool.cell_size * 0.5 - 0.5:
			over_water += 1
	check_eq(over_water, 0, "and no point of it is over the water")
