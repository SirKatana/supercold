extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _j(pose: PackedVector3Array, joint: StringName) -> Vector3:
	return pose[Humanoid.index_of(joint)]


func test_two_bone_reach_keeps_both_lengths_and_touches_the_goal() -> void:
	var root := Vector3(0.2, 1.46, 0)
	for goal: Vector3 in [Vector3(0.05, 1.5, -0.08), Vector3(0.3, 1.0, -0.4), Vector3(-0.1, 1.7, -0.2)]:
		var solved: Array[Vector3] = Humanoid.two_bone(root, goal, 0.30, 0.39, Vector3(1, -0.5, 0))
		check_near(root.distance_to(solved[0]), 0.30, 0.0005, "upper bone length for goal %s" % goal)
		check_near(solved[0].distance_to(solved[1]), 0.39, 0.0005, "lower bone length for goal %s" % goal)
		check_near(solved[1].distance_to(goal), 0.0, 0.002, "reaches the goal %s" % goal)
	var far: Array[Vector3] = Humanoid.two_bone(root, Vector3(5, 1.46, 0), 0.30, 0.39, Vector3.DOWN)
	check(far[1].distance_to(root) < 0.70, "a goal out of reach is pulled in, not stretched to")


func test_clutch_puts_both_hands_on_the_throat_with_exact_arm_lengths() -> void:
	var rest: PackedVector3Array = Humanoid.rest_local()
	for amount: float in [0.3, 0.7, 1.0]:
		var p: PackedVector3Array = Humanoid.pose(0.0, 0.0, 0.0, 0.0, 0.0, false, amount, 0.6)
		for side: String in ["l", "r"]:
			var shoulder: StringName = StringName("shoulder_" + side)
			var elbow: StringName = StringName("elbow_" + side)
			var wrist: StringName = StringName("wrist_" + side)
			check_near(_j(p, shoulder).distance_to(_j(p, elbow)), _j(rest, shoulder).distance_to(_j(rest, elbow)), 0.002, "upper arm %s at clutch %.1f" % [side, amount])
			check_near(_j(p, elbow).distance_to(_j(p, wrist)), _j(rest, elbow).distance_to(_j(rest, wrist)), 0.002, "forearm %s at clutch %.1f" % [side, amount])
	var full: PackedVector3Array = Humanoid.pose(0.0, 0.0, 0.0, 0.0, 0.0, false, 1.0, 0.6)
	check(_j(full, &"hand_l").distance_to(_j(full, &"neck")) < 0.13, "left hand at the neck (%.2f m)" % _j(full, &"hand_l").distance_to(_j(full, &"neck")))
	check(_j(full, &"hand_r").distance_to(_j(full, &"neck")) < 0.13, "right hand at the neck")
	check(_j(full, &"elbow_l").y < _j(full, &"shoulder_l").y - 0.15, "elbows hang below the shoulders, not out in a T")


func test_bend_doubles_him_over_with_feet_still_on_the_floor() -> void:
	var up: PackedVector3Array = Humanoid.pose(0.0, 0.0, 0.0, 0.0, 0.0)
	var over: PackedVector3Array = Humanoid.pose(0.0, 0.0, 0.0, 0.0, 0.0, false, 1.0, 1.0)
	check(_j(over, &"head").y < _j(up, &"head").y - 0.35, "head comes well down (%.2f to %.2f)" % [_j(up, &"head").y, _j(over, &"head").y])
	check(_j(over, &"head").z < -0.45, "and forward (z=%.2f)" % _j(over, &"head").z)
	check_near(minf(_j(over, &"ankle_l").y, _j(over, &"ankle_r").y), Humanoid.REST[&"ankle_l"].y, 0.002, "feet planted")
	check(_j(over, &"knee_l").z < _j(over, &"hip_l").z, "knees give forwards, not backwards")


func test_choking_dude_clutches_bends_gags_and_dies_forward() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for group: StringName in [&"enemies", &"barrels"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	Game.alive_enemies = 0
	var spot: Vector3 = Game.data.cell_center(Vector2i(8, 8), 0.05)
	Game.player.global_position = Game.data.cell_center(Vector2i(2, 2), 0.05)
	var dude: PinkDude = Game.spawn_dude(spot, true)
	dude.sense_override = true
	var cloud := FartCloud.new()
	Game.entities_root(self).add_child(cloud)
	cloud.global_position = spot + Vector3(0.5, 1.1, 0)
	cloud.burst()
	Sfx.history.clear()
	var head_start: float = dude.joints[Humanoid.index_of(&"head")].y
	await wait_physics(70)
	check(dude.choking, "choking")
	var neck: Vector3 = dude.joints[Humanoid.index_of(&"neck")]
	check(dude.joints[Humanoid.index_of(&"hand_l")].distance_to(neck) < 0.16, "left hand on his neck")
	check(dude.joints[Humanoid.index_of(&"hand_r")].distance_to(neck) < 0.16, "right hand on his neck")
	check(dude.joints[Humanoid.index_of(&"head")].y < head_start - 0.3, "bent right over")
	check(Sfx.history.has(&"choke"), "the gagging sound played")
	await wait_physics(int(T.fart_kill_time * 60.0) + 30)
	check(not is_instance_valid(dude) or not dude.alive, "the smell killed him")
	check(Sfx.history.has(&"choke_die"), "with a last wheeze")
	check_eq(get_tree().get_nodes_in_group(&"ragdolls").size(), 1, "and he collapsed where he stood")


func test_cloud_is_fog_not_a_shape() -> void:
	var cloud := FartCloud.new()
	add_child(cloud)
	var puffs: int = 0
	for child: Node in cloud.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null:
			continue
		puffs += 1
		check(mi.mesh is QuadMesh, "a puff is a flat camera-facing quad")
	check(puffs >= 60, "dozens of overlapping puffs (%d)" % puffs)
	var material: StandardMaterial3D = Mats.fart()
	check_eq(material.billboard_mode, BaseMaterial3D.BILLBOARD_ENABLED, "always faces the camera")
	check(material.albedo_texture is GradientTexture2D, "soft round falloff, no hard edge")
	check(material.albedo_color.g > material.albedo_color.r and material.albedo_color.g > material.albedo_color.b * 3.0, "green")
	check(material.albedo_color.a < 0.5, "thin enough to see through")
	check(material.proximity_fade_enabled, "and it fades where it meets walls and bodies")
	var shown_small: int = 0
	for child: Node in cloud.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			shown_small += 1
	cloud.burst()
	await wait_physics(60)
	var shown_big: int = 0
	for child: Node in cloud.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			shown_big += 1
	check(shown_big > shown_small * 3, "a burst cloud shows far more fog (%d then %d)" % [shown_small, shown_big])
	cloud.free()


func _empty_room() -> Vector3:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for group: StringName in [&"enemies", &"barrels"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	Game.alive_enemies = 0
	Game.player.global_position = Game.data.cell_center(Vector2i(2, 2), 0.05)
	return Game.data.cell_center(Vector2i(8, 8), 0.05)


func test_thrown_fart_grenade_fills_the_room_with_fog_where_it_lands() -> void:
	var spot: Vector3 = await _empty_room()
	var grenade: FartGrenade = FartGrenade.create()
	Game.entities_root(self).add_child(grenade)
	check_eq(get_tree().get_nodes_in_group(&"fart_clouds").size(), 0, "no fog anywhere before it is thrown")
	var from: Vector3 = spot + Vector3(-7, 1.4, 0)
	grenade.throw_from(from, Vector3(8, 2, 0), null)
	await wait_physics(140)
	check(not is_instance_valid(grenade), "the grenade is spent")
	var cloud: FartCloud = get_tree().get_first_node_in_group(&"fart_clouds") as FartCloud
	check(cloud != null and cloud.big, "fog is out, and it is the room-filling kind")
	check(cloud.global_position.x > from.x + 3.0, "where the grenade landed, not where it was thrown from")
	check(cloud.radius > T.fart_big_radius * 0.8, "rolled out to full size (%.1f m)" % cloud.radius)
	check(Sfx.history.has(&"fart"), "with the noise")


func test_fart_grenade_chokes_dudes_to_death_and_spares_gas_masks() -> void:
	var spot: Vector3 = await _empty_room()
	var dude: PinkDude = Game.spawn_dude(spot + Vector3(1.5, 0, 0), true)
	var other: PinkDude = Game.spawn_dude(spot + Vector3(-1.5, 0, -2.0), true, &"rifle")
	var trooper: PinkDude = Game.spawn_dude(spot + Vector3(0, 0, 2.5), true, &"shield")
	for d: PinkDude in [dude, other, trooper]:
		d.sense_override = true
	var grenade: FartGrenade = FartGrenade.create()
	Game.entities_root(self).add_child(grenade)
	grenade.global_position = spot + Vector3(0, 0.3, 0)
	grenade.go_off()
	await wait_physics(60)
	check(dude.choking and other.choking, "both are choking")
	check(not dude.has_weapon(), "and have dropped their guns to grab their throats")
	await wait_physics(int(T.fart_kill_time * 60.0) + 40)
	check(not is_instance_valid(dude) or not dude.alive, "the first one died of it")
	check(not is_instance_valid(other) or not other.alive, "so did the second")
	check(is_instance_valid(trooper) and trooper.alive, "the trooper's gas mask saved him")


func test_shooting_a_fart_grenade_sets_it_off() -> void:
	var spot: Vector3 = await _empty_room()
	var grenade: FartGrenade = FartGrenade.create()
	Game.entities_root(self).add_child(grenade)
	grenade.global_position = spot + Vector3(0, 1.0, 0)
	await wait_physics(2)
	BulletPool.for_node(Game.player).fire(spot + Vector3(-4, 1.0, 0), Vector3.RIGHT, null)
	await wait_physics(40)
	check(not is_instance_valid(grenade), "gone")
	check(get_tree().get_nodes_in_group(&"fart_clouds").size() == 1, "fog where it lay")


func test_no_floor_has_fog_lying_about_any_more() -> void:
	for floor_name: String in ["f15_restrooms", "f18_beanworks"]:
		check(Game.load_level(floor_name), "%s loads" % floor_name)
		await wait_physics(2)
		check_eq(get_tree().get_nodes_in_group(&"fart_clouds").size(), 0, "%s starts with clean air" % floor_name)
		var grenades: int = 0
		for node: Node in get_tree().get_nodes_in_group(&"pickups"):
			if node is FartGrenade:
				grenades += 1
		check(grenades >= 5, "%s has stink grenades to find (%d)" % [floor_name, grenades])
