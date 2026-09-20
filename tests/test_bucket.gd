extends "res://tests/test_case.gd"

var _spot: Vector3


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for group: StringName in [&"enemies", &"barrels"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	Game.alive_enemies = 0
	_spot = Game.data.cell_center(Vector2i(8, 8), 0.05)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _spills() -> Array[Puddle]:
	var out: Array[Puddle] = []
	for node: Node in get_tree().get_nodes_in_group(&"puddles"):
		if (node as Puddle).radius > 0.0:
			out.append(node)
	return out


func _hold_bucket_facing(target: Vector3, from: Vector3) -> WaterBucket:
	var bucket: WaterBucket = WaterBucket.create()
	Game.entities_root(self).add_child(bucket)
	Game.player.global_position = from
	Game.player.look_at(Vector3(target.x, from.y, target.z))
	Game.player.head.rotation.x = -0.2
	Game.player.hands.pick_up(bucket)
	return bucket


func test_pouring_soaks_the_dude_in_front_and_he_goes_down_at_once() -> void:
	var dude: PinkDude = Game.spawn_dude(_spot, true)
	dude.sense_override = true
	dude.set_physics_process(false)
	dude.desired_velocity = Vector3.ZERO
	var bucket: WaterBucket = _hold_bucket_facing(_spot, _spot + Vector3(-2.6, 0, 0))
	await wait_physics(2)
	check(bucket.full, "full")
	Game.player.hands.primary()
	check(not bucket.full, "poured out")
	check_eq(dude.state_name, &"slipped", "he was standing still and went over anyway")
	check(not dude.has_weapon(), "and lost his gun")
	check_eq(_spills().size(), 1, "one spill on the floor")
	check(_spills()[0].global_position.distance_to(_spot) < 1.2, "where he stood")
	check(Sfx.history.has(&"splash"), "with a splash")


func test_spill_lasts_a_minute_and_a_half_then_dries_up() -> void:
	check_eq(T.spill_seconds, 90.0, "ninety seconds")
	var bucket: WaterBucket = _hold_bucket_facing(_spot, _spot + Vector3(-3, 0, 0))
	await wait_physics(2)
	Game.player.hands.primary()
	var spill: Puddle = _spills()[0]
	check_near(spill.seconds_left(), 90.0, 0.5, "starts with the full ninety")
	TimeManager.override_scale = T.min_scale
	await wait_frames(60)
	check_near(spill.seconds_left(), 89.0, 0.3, "it dries on real time, even while the world crawls")
	# Skip ahead to the end rather than wait for it.
	spill._age = 86.0
	await wait_frames(4)
	check(spill._mesh.scale.x < 0.9, "shrinking as it dries")
	spill._age = 90.5
	await wait_frames(3)
	check(not is_instance_valid(spill), "gone")


func test_running_dude_slips_on_a_spill_later_on() -> void:
	var bucket: WaterBucket = _hold_bucket_facing(_spot, _spot + Vector3(-3, 0, 0))
	await wait_physics(2)
	Game.player.hands.primary()
	var spill: Puddle = _spills()[0]
	await wait_physics(30)
	var dude: PinkDude = Game.spawn_dude(spill.global_position + Vector3(0.4, 0.05, 0), true)
	dude.sense_override = true
	dude.set_physics_process(false)
	dude.desired_velocity = Vector3(3.2, 0, 0)
	await wait_physics(5)
	check_eq(dude.state_name, &"slipped", "anyone who runs through it goes down")


func test_empty_bucket_pours_nothing_and_gets_thrown_instead() -> void:
	var bucket: WaterBucket = _hold_bucket_facing(_spot, _spot + Vector3(-3, 0, 0))
	await wait_physics(2)
	Game.player.hands.primary()
	Game.player.hands.primary()
	check_eq(_spills().size(), 1, "still one spill")
	check(Game.player.hands.held == null, "the empty bucket was thrown")
	check_eq(bucket.state, Pickup.State.FLYING, "and is in the air")


func test_thrown_full_bucket_splashes_where_it_lands() -> void:
	var dude: PinkDude = Game.spawn_dude(_spot + Vector3(6, 0, 0), true)
	dude.sense_override = true
	dude.set_physics_process(false)
	var bucket: WaterBucket = WaterBucket.create()
	Game.entities_root(self).add_child(bucket)
	var from: Vector3 = _spot + Vector3(0, 1.4, 0)
	bucket.throw_from(from, (dude.global_position + Vector3(0, 1.0, 0) - from).normalized() * T.throw_speed, null)
	await wait_physics(90)
	check_eq(_spills().size(), 1, "a spill where it hit")
	check(_spills()[0].global_position.distance_to(dude.global_position) < 1.5, "at the dude")
	check(not bucket.full, "bucket is empty now")
	check(dude.state_name == &"slipped" or dude.state_name == &"stunned" or not dude.has_weapon(), "and he took it badly")


func test_bucket_is_hollow_and_shows_its_water() -> void:
	var bucket: WaterBucket = WaterBucket.create()
	add_child(bucket)
	check(bucket._water.visible, "you can see the water in a full one")
	bucket._set_full(false)
	check(not bucket._water.visible, "and that an empty one is empty")
	var mesh: ArrayMesh = MeshKit.cached(&"water_bucket", WaterBucket._model)
	var ray_hits_a_lid: bool = false
	for surface: int in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			if absf(v.y - 0.24) < 0.02 and Vector2(v.x, v.z).length() < 0.05:
				ray_hits_a_lid = true
	check(not ray_hits_a_lid, "nothing covers the top")
	bucket.free()


func test_buckets_are_scattered_on_some_floors_not_all() -> void:
	var with_buckets: int = 0
	var total: int = 0
	for floor_name: String in Game.FLOORS:
		var d: LevelData = LevelParser.load_level(floor_name)
		var here: int = 0
		for p: Dictionary in d.pickups:
			if p["kind"] == &"bucket":
				here += 1
		total += here
		with_buckets += 1 if here > 0 else 0
	check(with_buckets >= 8 and with_buckets <= 16, "buckets on %d of 30 floors" % with_buckets)
	check(total >= 20, "%d buckets in the game" % total)
