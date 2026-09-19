extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


## Loads test_doors, hands the player a ram, and points them at a world position.
func _armed_player_facing(target: Vector3, from: Vector3) -> Ram:
	var ram: Ram = Ram.create()
	Game.entities_root(self).add_child(ram)
	Game.player.global_position = from
	Game.player.look_at(Vector3(target.x, from.y, target.z))
	Game.player.head.rotation.x = 0.0
	Game.player.hands.pick_up(ram)
	return ram


func _cool(ram: Ram) -> void:
	ram.cooldown_left = 0.0


func test_ram_starts_with_five_hits() -> void:
	var ram: Ram = Ram.create()
	check_eq(ram.durability, 5, "five bashes")
	check_eq(T.ram_hits, 5, "tuning agrees")
	check_eq(ram.blunt_damage, T.dude_hp, "a thrown ram kills a dude outright")


func test_split_rect_covers_everything_but_the_cell() -> void:
	var rect := Rect2i(2, 3, 5, 4)
	var pieces: Array[Rect2i] = WallBreach.split_rect(rect, Vector2i(4, 5))
	var covered: Dictionary[Vector2i, int] = {}
	for r: Rect2i in pieces:
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				covered[Vector2i(x, y)] = covered.get(Vector2i(x, y), 0) + 1
	check_eq(covered.size(), 5 * 4 - 1, "every cell but the hole")
	check(not covered.has(Vector2i(4, 5)), "the hole is open")
	for cell: Vector2i in covered:
		check_eq(covered[cell], 1, "no overlap at %s" % cell)


func test_outer_walls_never_break() -> void:
	var d: LevelData = LevelParser.load_level("test_doors")
	check(not WallBreach.can_break(d, Vector2i(0, 3)), "west boundary")
	check(not WallBreach.can_break(d, Vector2i(5, 0)), "north boundary")
	check(WallBreach.can_break(d, Vector2i(5, 3)), "interior wall between the two rooms")
	check(not WallBreach.can_break(d, Vector2i(2, 2)), "floor is not a wall")


func test_door_costs_one_bash() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var door: Door = get_tree().get_first_node_in_group(&"doors") as Door
	var ram: Ram = _armed_player_facing(door.global_position, door.global_position + Vector3(-1.6, 0.05, 0))
	await wait_physics(2)
	check(Game.player.hands.held == ram, "holding the ram")
	Game.player.hands.primary()
	await wait_frames(2)
	check(not is_instance_valid(door) or door.is_broken, "one bash opens a door")
	check_eq(ram.durability, T.ram_hits - 1, "and costs one hit")


func test_wall_cracks_then_breaks_and_opens_a_path() -> void:
	check(Game.load_level("test_doors"), "level loads")
	check(await LevelValidator.wait_until_synced(Game.level, Game.data), "nav synced")
	var cell := Vector2i(5, 3)
	var target: Vector3 = Game.data.cell_center(cell, 0.05)
	var ram: Ram = _armed_player_facing(target, target + Vector3(-2.0, 0, 0))
	await wait_physics(2)
	check_eq(Game.data.char_at(cell), "#", "solid before")

	Game.player.hands.primary()
	await wait_frames(2)
	check_eq(Game.data.char_at(cell), "#", "one bash only cracks it")
	check(Game.level.get_node_or_null("Cracks_5_3") != null, "cracks are drawn on the wall")
	check_eq(ram.durability, T.ram_hits - 1, "first bash spent")

	_cool(ram)
	Game.player.hands.primary()
	await wait_physics(3)
	check_eq(Game.data.char_at(cell), ".", "second bash opens the cell")
	check(Game.level.get_node_or_null("Cracks_5_3") == null or Game.level.get_node("Cracks_5_3").is_queued_for_deletion(), "cracks removed")
	check(Game.level.get_node_or_null("Rubble_5_3") != null, "rubble left behind")
	check_eq(ram.durability, T.ram_hits - T.ram_wall_hits, "a wall costs %d" % T.ram_wall_hits)

	# The ray that hit the wall before now passes through.
	var space: PhysicsDirectSpaceState3D = Game.level.get_world_3d().direct_space_state
	var through := PhysicsRayQueryParameters3D.create(target + Vector3(-1.5, 1.2, 0), target + Vector3(1.5, 1.2, 0), 1)
	check(space.intersect_ray(through).is_empty(), "the breach is open to walk and shoot through")

	# Wait for the threaded rebake, then ask the navmesh for a route through the hole.
	var map: RID = (Game.level.get_node(^"Nav") as NavigationRegion3D).get_navigation_map()
	var crossed: bool = false
	for i: int in 120:
		await wait_physics(1)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, target + Vector3(-2, 0, 0), target + Vector3(2, 0, 0), true)
		if path.size() >= 2 and path[path.size() - 1].distance_to(target + Vector3(2, 0, 0)) < 1.0:
			var length: float = 0.0
			for p: int in range(1, path.size()):
				length += path[p].distance_to(path[p - 1])
			if length < 5.5:
				crossed = true
				break
	check(crossed, "dudes can path straight through the breach")


func test_ram_cracks_in_half_after_its_last_hit() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var cell := Vector2i(5, 1)
	var target: Vector3 = Game.data.cell_center(cell, 0.05)
	var ram: Ram = _armed_player_facing(target, target + Vector3(-2.0, 0, 0))
	await wait_physics(2)
	ram.durability = 1
	var state: Dictionary = {"cracked": false}
	ram.cracked.connect(func() -> void: state["cracked"] = true)
	Game.player.hands.primary()
	await wait_frames(3)
	check(state["cracked"], "cracked signal")
	check(not is_instance_valid(ram), "the ram is gone")
	check(Game.player.hands.held == null, "hands are empty")
	check_eq(get_tree().get_nodes_in_group(&"debris").size(), 2, "two halves on the floor")


func test_bashing_an_unbreakable_wall_is_free() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var target: Vector3 = Game.data.cell_center(Vector2i(0, 2), 0.05)
	var ram: Ram = _armed_player_facing(target, target + Vector3(2.0, 0, 0))
	await wait_physics(2)
	Game.player.hands.primary()
	await wait_frames(2)
	check_eq(ram.durability, T.ram_hits, "the outer wall shrugs it off and costs nothing")


func test_thrown_ram_kills_a_dude_and_cracks_in_half() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	await wait_frames(2)
	var spot: Vector3 = Game.data.cell_center(Vector2i(8, 2), 0.05)
	var dude: PinkDude = Game.spawn_dude(spot, true)
	dude.sense_override = true
	await wait_physics(2)
	var ram: Ram = Ram.create()
	Game.entities_root(self).add_child(ram)
	var from: Vector3 = spot + Vector3(-4, 1.3, 0)
	ram.throw_from(from, (spot + Vector3(0, 1.1, 0) - from).normalized() * T.throw_speed, null)
	await wait_physics(60)
	check(not is_instance_valid(dude) or not dude.alive, "the dude is dead")
	check(not is_instance_valid(ram), "the ram broke")
	check_eq(get_tree().get_nodes_in_group(&"debris").size(), 2, "into two halves")


func test_ram_bash_kills_a_dude() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	await wait_frames(2)
	var spot: Vector3 = Game.data.cell_center(Vector2i(8, 2), 0.05)
	var dude: PinkDude = Game.spawn_dude(spot, true)
	dude.sense_override = true
	var ram: Ram = _armed_player_facing(spot, spot + Vector3(-1.5, 0, 0))
	await wait_physics(2)
	Game.player.hands.primary()
	await wait_frames(2)
	check(not is_instance_valid(dude) or not dude.alive, "a full swing kills")
	check_eq(ram.durability, T.ram_hits - 1, "and costs one hit")


func test_floors_that_should_have_a_ram_do() -> void:
	for floor_name: String in ["f2_offices", "f3_servers", "f4_labs", "f5_executive"]:
		var d: LevelData = LevelParser.load_level(floor_name)
		var rams: int = 0
		for entry: Dictionary in d.pickups:
			if entry["kind"] == &"ram":
				rams += 1
		check_eq(rams, 1, "%s has one wall breaker" % floor_name)
