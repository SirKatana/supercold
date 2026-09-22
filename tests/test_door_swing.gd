extends "res://tests/test_case.gd"
## Doors are a pair of hinged leaves now. They swing away from whoever walks up.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	check(Game.load_floor(1), "offices load")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _door() -> Door:
	return get_tree().get_first_node_in_group(&"doors") as Door


func test_a_closed_door_is_two_leaves_shut_in_a_frame() -> void:
	var d: Door = _door()
	check_eq(d._leaves.size(), 2, "a pair of leaves")
	check(absf(d._leaves[0].rotation.y) < 0.01 and absf(angle_difference(d._leaves[1].rotation.y, PI)) < 0.01, "both shut")
	check(d._frame != null and d._frame.mesh != null, "in a frame")
	check(not d.is_open(), "and it blocks the way")


func test_the_leaves_swing_away_from_whoever_walks_up() -> void:
	var d: Door = _door()
	var face: Vector3 = Vector3(0, 0, 1) if d.along_x else Vector3(1, 0, 0)
	for side: float in [1.0, -1.0]:
		var visitor: PinkDude = Game.spawn_dude(d.global_position + face * side * 1.0, true)
		visitor.sense_override = true
		await wait_physics(40)
		check(d.is_open(), "it opens for him")
		var tip: Vector3 = d._leaves[0].global_transform * Vector3(0.9, 1.0, 0.0)
		var away: float = (tip - d.global_position).dot(face) * side
		check(away < -0.5, "and the leaf swings away from him, not into his face (side %d, %.2f)" % [int(side), away])
		visitor.free()
		Game.alive_enemies = 0
		await wait_physics(40)
		check(not d.is_open(), "and shuts behind him")


func test_breaking_it_leaves_the_frame_in_the_wall() -> void:
	var d: Door = _door()
	var frame: MeshInstance3D = d._frame
	var where: Vector3 = frame.global_position
	d.take_damage(99, Vector3(0, 0, -1), d.global_position)
	await wait_physics(3)
	check(not is_instance_valid(d), "the door is gone")
	check(is_instance_valid(frame) and frame.is_inside_tree(), "the steel frame is not")
	check(frame.global_position.distance_to(where) < 0.01, "and it has not moved")


func _point_on_leaf(d: Door, leaf: int) -> Vector3:
	return d._visual.global_transform * Vector3((-1.0 if leaf == 0 else 1.0) * 0.5, 1.2, 0.0)


func test_shooting_one_leaf_breaks_that_leaf_only() -> void:
	var d: Door = _door()
	d.on_bullet_hit(null, _point_on_leaf(d, 1), Vector3.UP)
	d.on_bullet_hit(null, _point_on_leaf(d, 1), Vector3.UP)
	await wait_physics(2)
	check(d.leaf_broken[1] and not d.leaf_broken[0], "the leaf that was shot is gone, the other still hangs")
	check(is_instance_valid(d) and not d.is_broken, "the door is still a door")
	check(not d._leaves[1].visible and d._leaves[0].visible, "and it looks that way")
	check(d._leaf_shapes[1].disabled and not d._leaf_shapes[0].disabled, "you can get through the broken half only")
	d.on_bullet_hit(null, _point_on_leaf(d, 0), Vector3.UP)
	check(not d.leaf_broken[0], "one bullet does not break the other")
	d.on_bullet_hit(null, _point_on_leaf(d, 0), Vector3.UP)
	await wait_physics(2)
	check(not is_instance_valid(d), "two, and the doorway is clear")


func test_the_ram_takes_both_leaves() -> void:
	var d: Door = _door()
	d.smash(Vector3.FORWARD)
	await wait_physics(2)
	check(not is_instance_valid(d), "one bash, whole door")


func test_the_windows_are_glass_you_can_see_through() -> void:
	var leaf: ArrayMesh = MeshKit.cached(&"door_leaf", Door._model_leaf)
	var glass: int = -1
	for s: int in leaf.get_surface_count():
		if leaf.surface_get_material(s) == Mats.glass():
			glass = s
	check(glass >= 0, "the window is a pane of glass")
	check((Mats.glass() as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED, "and glass is see-through")
	# Nothing opaque sits in front of or behind the pane: no triangle of any other surface
	# covers the middle of the window, seen straight on.
	var w: float = T.cell_size * 0.5 - Door.JAMB - 0.006
	var middle := Vector2(w - Door.WINDOW_FROM_EDGE, Door.WINDOW_Y)
	for s: int in leaf.get_surface_count():
		if s == glass:
			continue
		var arrays: Array = leaf.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var covered: bool = false
		for t: int in range(0, indices.size(), 3):
			var a := Vector2(verts[indices[t]].x, verts[indices[t]].y)
			var b := Vector2(verts[indices[t + 1]].x, verts[indices[t + 1]].y)
			var c := Vector2(verts[indices[t + 2]].x, verts[indices[t + 2]].y)
			if Geometry2D.point_is_inside_triangle(middle, a, b, c):
				covered = true
				break
		check(not covered, "surface %d does not cover the window" % s)
