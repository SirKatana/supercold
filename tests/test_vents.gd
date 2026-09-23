extends "res://tests/test_case.gd"
## Ducts: break the grate, crawl through the wall, and meet what lives in there.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	check(Game.load_level("f11_sewers"), "the sewers load")
	await wait_physics(4)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _duct_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in Game.data.height:
		for x: int in Game.data.width:
			if Game.data.rows[y][x] == "v":
				cells.append(Vector2i(x, y))
	return cells


func test_a_duct_is_walled_off_until_you_break_the_grate() -> void:
	var grates: Array[Node] = get_tree().get_nodes_in_group(&"grates")
	check(grates.size() >= 2, "a duct opens into a room at both ends, got %d grates" % grates.size())
	var grate: VentGrate = grates[0]
	var from: Vector3 = grate.global_position + Vector3(0, 0.5, 0) + (grate.global_transform.basis.z if grate.along_x else grate.global_transform.basis.x) * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, grate.global_position + Vector3(0, 0.5, 0), 1 | 32)
	check(not Game.player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "the mouth is covered")
	grate.take_damage(99, Vector3.FORWARD)
	await wait_physics(3)
	check(not is_instance_valid(grate), "a couple of rounds take it out")


func test_the_player_crawls_in_a_duct_and_stands_up_after() -> void:
	var cells: Array[Vector2i] = _duct_cells()
	check(not cells.is_empty(), "this floor has ducts")
	var standing: float = Game.player.head.position.y
	Game.player.global_position = Game.data.cell_center(cells[0], 0.05)
	await wait_physics(4)
	check(Game.player.crawling, "in the duct he is on his hands and knees")
	check(Game.player.head.position.y < standing - 0.5, "his eyes are near the floor")
	check(Game.player.alive, "and he is fine")
	Game.player.global_position = Game.data.cell_center(Game.data.player_start, 0.05)
	await wait_physics(6)
	check(not Game.player.crawling, "out in the corridor he stands up again")
	check_eq(Game.player.head.position.y, standing, "eyes back where they were")


func test_dudes_cannot_use_the_ducts() -> void:
	var cells: Array[Vector2i] = _duct_cells()
	var map: RID = Game.level.get_node(^"Nav").get_navigation_map()
	await wait_physics(4)
	for cell: Vector2i in cells:
		var want: Vector3 = Game.data.cell_center(cell, 0.1)
		var nearest: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
		check(nearest.distance_to(want) > 0.6, "the navmesh does not reach into the duct at %s" % cell)


func test_the_lurker_waits_in_the_duct_and_is_not_part_of_clearing_the_floor() -> void:
	var lurkers: Array[Node] = get_tree().get_nodes_in_group(&"lurkers")
	check_eq(lurkers.size(), 1, "one of them is in there")
	var green: VentLurker = lurkers[0]
	check_eq(green.skin.material, Mats.lurker(), "green")
	check(VentDuct.inside(Game.data, green.global_position), "and he is in the ducts, not the corridor")
	check(not green.is_in_group(&"enemies"), "he is not counted as an enemy")
	var before: int = Game.alive_enemies
	await wait_physics(60)
	check_eq(green.mode, VentLurker.Mode.WAITING, "he stays put while you keep out")
	check_eq(Game.alive_enemies, before, "and the floor can be cleared without ever meeting him")


func test_he_comes_for_you_in_the_duct_grabs_you_and_can_be_killed_first() -> void:
	Game.god_mode = false
	var green: VentLurker = get_tree().get_nodes_in_group(&"lurkers")[0]
	var cells: Array[Vector2i] = _duct_cells()
	var nearest: Vector2i = cells[0]
	for cell: Vector2i in cells:
		if Game.data.cell_center(cell, 0.0).distance_to(green.global_position) < Game.data.cell_center(nearest, 0.0).distance_to(green.global_position):
			nearest = cell
	Game.player.global_position = Game.data.cell_center(nearest, 0.05)
	var held: Dictionary = {"yes": false}
	green.grabbed.connect(func(_p: Player) -> void: held["yes"] = true)
	for i: int in 400:
		await wait_physics(1)
		if held["yes"]:
			break
	check(held["yes"], "he took hold of you")
	check(Game.player.held_by == green, "and you are going nowhere")
	check(Game.player.alive, "not dead yet: you have a moment")
	green.on_punched(Game.player, green.global_position)
	green.on_punched(Game.player, green.global_position)
	await wait_physics(3)
	check(not is_instance_valid(green) or not green.alive, "two punches and he is finished")
	check(Game.player.held_by == null, "he lets go")
	check(Game.player.alive, "and you crawl on")


func test_he_kills_you_if_you_do_nothing() -> void:
	Game.god_mode = false
	var green: VentLurker = get_tree().get_nodes_in_group(&"lurkers")[0]
	Game.player.global_position = green.global_position + Vector3(0.6, 0, 0)
	for i: int in 500:
		await wait_physics(1)
		if not Game.player.alive:
			break
	check(not Game.player.alive, "he had you")
