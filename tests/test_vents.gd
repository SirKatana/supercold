extends "res://tests/test_case.gd"
## Ducts: break the grate, crawl through the wall, and meet what lives in there.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.lurker_always = true
	check(Game.load_level("f11_sewers"), "the sewers load")
	await wait_physics(4)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.lurker_always = false
	Game.unload_level()


func _duct_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in Game.data.height:
		for x: int in Game.data.width:
			if Game.data.rows[y][x] == "v" or Game.data.rows[y][x] == "e":
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


func test_a_duct_can_be_crawled_from_end_to_end() -> void:
	var cells: Array[Vector2i] = _duct_cells()
	check(cells.size() >= 6, "the ducts are a little maze, got %d cells" % cells.size())
	# Walk the maze from one cell to the one furthest from it, following the tunnel.
	var path: Array[Vector2i] = _path_across(cells)
	check(path.size() >= 4, "and there is a way across it, %d cells long" % path.size())
	Game.player.global_position = Game.data.cell_center(path[0], 0.05)
	await wait_physics(6)
	check(Game.player.crawling, "in it")
	for step: Vector2i in path:
		var target: Vector3 = Game.data.cell_center(step, 0.05)
		for i: int in 120:
			var to: Vector3 = (target - Game.player.global_position) * Vector3(1, 0, 1)
			Game.player.velocity = to.normalized() * 2.4
			Game.player.move_and_slide()
			await wait_physics(1)
			if Vector2(to.x, to.z).length() < 0.35:
				break
	var finish: Vector3 = Game.data.cell_center(path[path.size() - 1], 0.05)
	check(Game.player.global_position.distance_to(finish) < 0.7,
		"and out at the far end: %.2f m short" % Game.player.global_position.distance_to(finish))


## The longest way through the duct maze, walked cell by cell.
func _path_across(cells: Array[Vector2i]) -> Array[Vector2i]:
	var seen: Dictionary = {cells[0]: [cells[0]]}
	var queue: Array[Vector2i] = [cells[0]]
	var longest: Array[Vector2i] = [cells[0]]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = here + step
			if seen.has(next) or not cells.has(next):
				continue
			var route: Array = (seen[here] as Array).duplicate()
			route.append(next)
			seen[next] = route
			queue.append(next)
			if route.size() > longest.size():
				longest = []
				for cell: Variant in route:
					longest.append(cell as Vector2i)
	return longest


func test_e_pulls_a_grate_off_when_you_are_looking_at_it() -> void:
	var grate: VentGrate = get_tree().get_nodes_in_group(&"grates")[0]
	var facing: Vector3 = grate.global_transform.basis.z if grate.along_x else grate.global_transform.basis.x
	Game.player.global_position = grate.global_position + facing * 1.3 + Vector3(0, 0.05, 0)
	Game.player.look_at(grate.global_position + Vector3(0, VentDuct.HEIGHT * 0.5, 0))
	await wait_physics(3)
	Game.player.hands.interact()
	await wait_physics(3)
	check(not is_instance_valid(grate), "one press of use and it is off")


## Use once to take the grate off, use again to climb in, and once more to climb out. The gun
## stays in his hands the whole way.
func test_e_breaks_the_grate_then_climbs_you_in_and_out() -> void:
	var grate: VentGrate = get_tree().get_nodes_in_group(&"grates")[0]
	var mouth: Vector3 = grate.global_position
	var facing: Vector3 = grate.global_transform.basis.z if grate.along_x else grate.global_transform.basis.x
	var gun: Pistol = Pistol.create()
	Game.entities_root(self).add_child(gun)
	Game.player.hands.pick_up(gun)
	Game.player.global_position = mouth + facing * 1.5 + Vector3(0, 0.05, 0)
	Game.player.look_at(Vector3(mouth.x, Game.player.global_position.y, mouth.z))
	await wait_physics(3)
	Game.player.hands.interact()
	await wait_physics(3)
	check(not is_instance_valid(grate), "the first press takes the grate off")
	check(not Game.player.crawling, "and leaves you standing outside")
	Game.player.hands.interact()
	await wait_physics(3)
	check(Game.player.crawling, "the second press puts you in on your hands and knees")
	check(VentDuct.inside(Game.data, Game.player.global_position), "inside the duct")
	check(Game.player.hands.held == gun, "with your gun still in your hands")
	Game.player.hands.interact()
	await wait_physics(4)
	check(not VentDuct.inside(Game.data, Game.player.global_position), "and another press puts you back in the room")
	check(not Game.player.crawling, "standing up again")


## He is small enough to lie inside a duct, and he lies along it rather than across it.
func test_the_lurker_fits_inside_the_duct() -> void:
	var green: VentLurker = get_tree().get_nodes_in_group(&"lurkers")[0]
	await wait_physics(10)
	var widest: float = 0.0
	var centre: Vector3 = Game.data.cell_center(Game.data.cell_of(green.global_position), 0.0)
	for joint: Vector3 in green.joints:
		widest = maxf(widest, Vector2(joint.x - centre.x, joint.z - centre.z).length())
	check(widest < 1.15, "no part of him is outside the tunnel (furthest %.2f m from the middle)" % widest)
	check(VentLurker.BODY_SCALE < 0.8, "because he is a small thing")


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


func test_you_cannot_shoot_people_in_the_room_from_inside_a_duct() -> void:
	var cells: Array[Vector2i] = _duct_cells()
	var gun: Pistol = Pistol.create()
	Game.entities_root(self).add_child(gun)
	Game.player.hands.pick_up(gun)
	var rounds: int = gun.ammo
	# Outside, in the room: firing works as always.
	Game.player.global_position = Game.data.cell_center(Game.data.player_start, 0.05)
	await wait_physics(4)
	Game.player.hands.primary()
	await wait_physics(2)
	check_eq(gun.ammo, rounds - 1, "in the open he fires")
	# Inside the duct, aiming down the tunnel at nothing: no shot.
	Game.player.global_position = Game.data.cell_center(cells[0], 0.05)
	await wait_physics(6)
	check(Game.player.crawling, "he is in the duct")
	gun.cooldown_left = 0.0
	rounds = gun.ammo
	for i: int in 8:
		Game.player.hands.primary()
		gun.cooldown_left = 0.0
		await wait_physics(1)
	check_eq(gun.ammo, rounds, "and the gun stays down: no picking people off through a grate")


func test_but_you_can_shoot_what_is_in_the_duct_with_you() -> void:
	var green: VentLurker = get_tree().get_nodes_in_group(&"lurkers")[0]
	var gun: Pistol = Pistol.create()
	Game.entities_root(self).add_child(gun)
	Game.player.hands.pick_up(gun)
	Game.player.global_position = green.global_position + (green.global_transform.basis.z * 1.6)
	Game.player.look_at(green.global_position + Vector3(0, 0.35, 0))
	await wait_physics(6)
	gun.cooldown_left = 0.0
	var rounds: int = gun.ammo
	Game.player.hands.primary()
	await wait_physics(2)
	check_eq(gun.ammo, rounds - 1, "he can shoot the thing that is in there with him")
