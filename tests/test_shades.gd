extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for group: StringName in [&"enemies", &"barrels", &"buried"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _dude(kind: StringName = &"pistol") -> PinkDude:
	var d: PinkDude = Game.spawn_dude(Game.data.cell_center(Vector2i(8, 8), 0.05), true, kind)
	d.sense_override = true
	d.set_physics_process(false)
	d._animate(0.0)
	return d


func test_every_kind_of_dude_wears_shades_except_a_copy() -> void:
	for kind: StringName in [&"pistol", &"rifle", &"shotgun", &"shield", &"runner", &"sniper", &"smg", &"knifeman", &"spearman", &"cloner"]:
		var d: PinkDude = _dude(kind)
		check(d.skin.has_sunglasses(), "%s dude has sunglasses" % kind)
		d.free()
	for boss: PinkDude in [Brute.new(), Director.new()]:
		Game.entities_root(self).add_child(boss)
		check(boss.skin.has_sunglasses(), "%s has them too" % boss.get_script().get_global_name())
		boss.free()
	# A copy is a copy of the man, not of what he was wearing.
	var copy := Cloner.new()
	copy.is_copy = true
	Game.entities_root(self).add_child(copy)
	check(not copy.skin.has_sunglasses(), "a clone has none")
	copy.free()


func test_shades_sit_on_the_face_and_turn_with_him() -> void:
	var d: PinkDude = _dude()
	d.look_at(d.global_position + Vector3(5, 0, 0))
	d._animate(0.0)
	var at: Transform3D = d.skin.shades_transform()
	var head: Vector3 = d.joints[Humanoid.index_of(&"head")]
	check(at.origin.distance_to(head) < 0.06, "on the head")
	var lens_point: Vector3 = at * Vector3(0, 0.022, -0.110)
	var facing: Vector3 = -d.global_transform.basis.z
	check((lens_point - head).normalized().dot(facing) > 0.85, "lenses are on the front of the face, the way he is looking")
	check(lens_point.y > head.y, "at eye height, above the middle of the head")


func test_shades_mesh_is_a_pair_of_glasses() -> void:
	var mesh: ArrayMesh = Humanoid.shades_mesh()
	var size: Vector3 = mesh.get_aabb().size
	check(size.x > 0.15 and size.x < 0.19, "as wide as a face (%.3f)" % size.x)
	check(size.y < 0.05, "and low, like glasses not goggles (%.3f)" % size.y)
	check(size.z > 0.11, "with arms reaching back to the ears (%.3f)" % size.z)
	check_eq(mesh.get_surface_count(), 2, "dark lenses and a frame")


func test_shades_fall_off_when_he_dies_and_the_body_has_none() -> void:
	var d: PinkDude = _dude()
	var where: Vector3 = d.skin.shades_transform().origin
	d.on_bullet_hit(null, d.global_position + Vector3.UP, Vector3.LEFT)
	var loose: Array[Node] = get_tree().get_nodes_in_group(&"lost_shades")
	check_eq(loose.size(), 1, "one pair came off")
	check((loose[0] as Node3D).global_position.distance_to(where) < 0.05, "from where they were on his face")
	var body: Ragdoll = get_tree().get_first_node_in_group(&"ragdolls") as Ragdoll
	check(body != null and not body._skin.has_sunglasses(), "and the body is not wearing any")
	await wait_physics(150)
	check(is_instance_valid(loose[0]) and (loose[0] as Node3D).global_position.y < 0.15, "they end up on the floor")
	check((loose[0] as Debris)._resting, "and lie still")


func test_shades_come_off_however_he_dies() -> void:
	for style: StringName in [&"ragdoll", &"ice", &"melt"]:
		for node: Node in get_tree().get_nodes_in_group(&"lost_shades"):
			node.free()
		var d: PinkDude = _dude()
		d.die(d.global_position, Vector3.RIGHT, style)
		check_eq(get_tree().get_nodes_in_group(&"lost_shades").size(), 1, "%s: shades on the floor" % style)


func test_frozen_dude_keeps_his_shades_black() -> void:
	var d: PinkDude = _dude()
	d.freeze(3.0)
	check(d.skin.has_sunglasses(), "still on")
	check_eq(d.skin._shades.material_override, null, "and not turned to ice")


func test_the_pause_menu_can_take_them_off_everyone_and_put_them_back() -> void:
	var dude: PinkDude = Game.spawn_dude(Vector3(0, 0.05, -4), true) if Game.level != null else null
	if dude == null:
		check(Game.load_level("test_room"), "test room loads")
		dude = Game.spawn_dude(Vector3(0, 0.05, -4), true)
	await wait_physics(2)
	check(dude.skin.has_sunglasses(), "on by default")
	Settings.sunglasses = false
	Settings.changed.emit()
	check(not dude.skin.has_sunglasses(), "off the moment the setting changes")
	var later: PinkDude = Game.spawn_dude(Vector3(2, 0.05, -4), true)
	await wait_physics(2)
	check(not later.skin.has_sunglasses(), "and new dudes arrive without them")
	var before: int = get_tree().get_nodes_in_group(&"lost_shades").size()
	later.die()
	check_eq(get_tree().get_nodes_in_group(&"lost_shades").size(), before, "nothing falls off a dude who had none")
	Settings.sunglasses = true
	Settings.changed.emit()
	check(dude.skin.has_sunglasses(), "back on")
	Game.unload_level()
