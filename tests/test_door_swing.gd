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
