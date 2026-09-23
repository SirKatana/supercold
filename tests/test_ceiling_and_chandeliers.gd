extends "res://tests/test_case.gd"
## The ceiling is solid, a flung body stops against it, and what hangs there rings.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	check(Game.load_floor(4), "the executive floor loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func test_the_ceiling_stops_a_bullet() -> void:
	var ceiling: StaticBody3D = Game.level.find_children("Ceiling", "StaticBody3D", true, false)[0]
	check_eq(ceiling.collision_layer, LevelBuilder.LAYER_WORLD, "it is on the world layer")
	var from: Vector3 = Game.player.global_position + Vector3(0, 1.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 12.0, LevelBuilder.LAYER_WORLD)
	var hit: Dictionary = Game.player.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty(), "a shot at the roof hits something")
	check(hit.get("position", Vector3.ZERO).y < T.wall_height + 0.3, "and it is the ceiling, at %.1f m" % (hit.get("position", Vector3.ZERO) as Vector3).y)


func test_a_body_thrown_up_hard_stays_under_the_roof() -> void:
	var at: Transform3D = Transform3D(Basis.IDENTITY, Game.player.global_position + Vector3(2, 0.05, 0))
	var body: Ragdoll = Ragdoll.spawn_standing(Game.entities_root(self), at, Vector3.UP * 30.0, Mats.pink(), 1.0)
	check(body.ceiling_y < T.wall_height + 0.01, "it knows where the roof is")
	var highest: float = 0.0
	for i: int in 120:
		await wait_physics(1)
		for p: Vector3 in body.pos:
			highest = maxf(highest, p.y)
	check(highest <= T.wall_height + 0.05, "nothing went through it (highest %.2f m of %.2f)" % [highest, T.wall_height])
	check(highest > 2.0, "but it really was flung up there")


func test_a_body_flung_into_a_chandelier_sets_it_swinging_and_ringing() -> void:
	var lights: Array[Node] = get_tree().get_nodes_in_group(&"hanging")
	check(lights.size() >= 1, "the executive floor has chandeliers, got %d" % lights.size())
	var light: Chandelier = lights[0]
	check(light.rotation.x == 0.0 and light.rotation.z == 0.0, "hanging straight")
	Sfx.history.clear()
	var under: Vector3 = light.global_position - Vector3(0, 2.2, 0)
	var body: Ragdoll = Ragdoll.spawn_standing(Game.entities_root(self), Transform3D(Basis.IDENTITY, under), Vector3.UP * 26.0, Mats.pink(), 1.0)
	for i: int in 150:
		await wait_physics(1)
		if Sfx.history.has(&"jingle"):
			break
	check(Sfx.history.has(&"jingle"), "it jingled")
	await wait_physics(10)
	check(absf(light.rotation.x) + absf(light.rotation.z) > 0.02, "and it is swinging")
	check(is_instance_valid(body), "the body is still there")


func test_a_chandelier_is_scenery_and_never_blocks_anything() -> void:
	var light: Chandelier = get_tree().get_nodes_in_group(&"hanging")[0]
	for child: Node in light.get_children():
		check(not (child is CollisionObject3D), "nothing on it collides")
	var from: Vector3 = light.global_position - Vector3(3, 1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(6, 0, 0), LevelBuilder.LAYER_WORLD | 32)
	check(Game.player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "and a shot goes straight past it")


func test_firing_barely_moves_the_clock_so_you_watch_the_round_go() -> void:
	check(T.burst_strength_shot <= 0.12, "a shot nudges the world to %.2f, no more" % T.burst_strength_shot)
	var gun: Pistol = Pistol.create()
	Game.entities_root(self).add_child(gun)
	Game.player.hands.pick_up(gun)
	TimeManager.override_scale = -1.0
	await wait_physics(40)
	Game.player.hands.primary()
	await wait_physics(2)
	var pool: BulletPool = BulletPool.for_node(Game.level)
	var round_in_air: Bullet = null
	for b: Node in pool.get_children():
		if b is Bullet and (b as Bullet).active:
			round_in_air = b
	check(round_in_air != null, "a round is in the air")
	var was: Vector3 = round_in_air.global_position
	await wait_physics(30)
	var covered: float = was.distance_to(round_in_air.global_position)
	check(covered < 1.2, "and standing still it crawls: %.2f m in half a second" % covered)
