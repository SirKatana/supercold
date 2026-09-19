extends "res://tests/test_case.gd"

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	var floor_body: StaticBody3D = LevelBuilder.make_box(Vector3(40, 1, 40), Mats.floor_mat())
	world.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	await wait_physics(2)


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func _drop(impulse: Vector3) -> Ragdoll:
	return Ragdoll.spawn_standing(world, Transform3D.IDENTITY, impulse, Mats.arm(), 1.0)


func test_has_every_joint_of_a_human() -> void:
	var r: Ragdoll = _drop(Vector3.ZERO)
	for joint: StringName in [&"head", &"neck", &"chest", &"spine", &"pelvis",
			&"shoulder_l", &"shoulder_r", &"elbow_l", &"elbow_r", &"wrist_l", &"wrist_r", &"hand_l", &"hand_r",
			&"hip_l", &"hip_r", &"knee_l", &"knee_r", &"ankle_l", &"ankle_r", &"toe_l", &"toe_r"]:
		check(r.names.has(joint), "missing joint %s" % joint)
	check_eq(r.names.size(), 21, "twenty-one joints")
	check_near(r.point(&"head").y, 1.70, 0.001, "stands 1.8 m tall before it falls")


func test_bones_keep_their_length_while_it_falls() -> void:
	var r: Ragdoll = _drop(Vector3(2.5, 1.0, -2.0))
	var worst: float = 0.0
	for tick: int in 240:
		await wait_physics(1)
		for bone: Array in Ragdoll.BONES:
			var stretch: float = absf(r.bone_length(bone[0], bone[1]) - r.rest_length(bone[0], bone[1]))
			worst = maxf(worst, stretch / r.rest_length(bone[0], bone[1]))
	check(worst < 0.12, "no limb stretched more than 12 percent (worst %.0f%%)" % (worst * 100.0))


func test_it_falls_lands_on_the_floor_and_settles() -> void:
	var r: Ragdoll = _drop(Vector3(3.0, 1.0, 0.5))
	await wait_physics(30)
	check(r.point(&"head").y < 1.69, "it is falling")
	await wait_physics(330)
	check(r.point(&"head").y < 0.6, "the head ended up near the floor (y=%.2f)" % r.point(&"head").y)
	for i: int in r.pos.size():
		check(r.pos[i].y > -0.05, "%s sank through the floor (y=%.2f)" % [r.names[i], r.pos[i].y])
	check(r.motion() < 0.25, "it came to rest (motion %.3f m/s)" % r.motion())


func test_joint_limits_hold() -> void:
	var r: Ragdoll = _drop(Vector3(-2.0, 2.0, 3.0))
	var min_knee: float = INF
	var min_neck: float = INF
	var max_knee: float = 0.0
	for tick: int in 300:
		await wait_physics(1)
		min_knee = minf(min_knee, r.bone_length(&"hip_l", &"ankle_l") / r.rest_length(&"hip_l", &"ankle_l"))
		max_knee = maxf(max_knee, r.bone_length(&"hip_l", &"ankle_l") / r.rest_length(&"hip_l", &"ankle_l"))
		min_neck = minf(min_neck, r.bone_length(&"head", &"chest") / r.rest_length(&"head", &"chest"))
	check(min_knee > 0.36, "the knee never folds flat (%.2f)" % min_knee)
	check(max_knee < 1.08, "the leg never stretches past straight (%.2f)" % max_knee)
	check(min_neck > 0.74, "the neck never folds onto the chest (%.2f)" % min_neck)


func test_it_stops_at_walls() -> void:
	var wall: StaticBody3D = LevelBuilder.make_box(Vector3(0.5, 4, 10), Mats.wall())
	world.add_child(wall)
	wall.global_position = Vector3(2.0, 2.0, 0)
	await wait_physics(2)
	var r: Ragdoll = _drop(Vector3(7.0, 1.0, 0))
	await wait_physics(240)
	for i: int in r.pos.size():
		check(r.pos[i].x < 1.8, "%s went through the wall (x=%.2f)" % [r.names[i], r.pos[i].x])


func test_player_death_spawns_a_ragdoll_and_restart_clears_it() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var player: Player = Game.player
	var where: Vector3 = player.global_position
	player.die()
	check(player.ragdoll != null, "ragdoll spawned")
	check(player.ragdoll.point(&"pelvis").distance_to(where + Vector3(0, 0.96, 0)) < 0.45, "where the player stood")
	check(not player.hands.visible, "first-person arms hidden")
	await wait_physics(40)
	check(player.camera.global_position.distance_to(where) > 1.0, "the camera pulled back to watch")
	Game.restart_floor()
	await wait_physics(2)
	check_eq(get_tree().get_nodes_in_group(&"ragdolls").size(), 0, "restart removed the body")
	check(Game.player.alive, "fresh player")
