extends "res://tests/test_case.gd"
## Rows of rack cells are one shelving unit each, and pillars stand on a stone base. Both are
## still plain fixed boxes to the physics.


func after_each() -> void:
	Game.unload_level()


func _runs(data: LevelData) -> Array:
	var cells: Dictionary = {}
	for prop: Dictionary in data.props:
		if prop["kind"] == &"rack":
			cells[prop["cell"]] = true
	var runs: Array = []
	for cell: Vector2i in cells:
		if cells.has(cell + Vector2i(0, -1)):
			continue
		var n: int = 1
		while cells.has(cell + Vector2i(0, n)):
			n += 1
		runs.append(n)
	return runs


func test_a_row_of_racks_is_one_bookshelf() -> void:
	check(Game.load_floor(2), "server room loads")
	await wait_physics(3)
	var runs: Array = _runs(Game.data)
	var units: Array[Node] = get_tree().get_nodes_in_group(&"shelving")
	check_eq(units.size(), runs.size(), "one unit per row, not one per cell")
	check(runs.max() >= 4, "and the server room's rows are four cells long")
	var longest: StaticBody3D = null
	for unit: Node in units:
		var shape: BoxShape3D = ((unit as StaticBody3D).get_child(0) as CollisionShape3D).shape
		if longest == null or shape.size.z > (((longest.get_child(0)) as CollisionShape3D).shape as BoxShape3D).size.z:
			longest = unit
	var box: BoxShape3D = (longest.get_child(0) as CollisionShape3D).shape
	check_eq(box.size, Furniture.shelf_size(runs.max()), "one solid block the length of the row")
	# World, and a breakable: shelving can be brought down now.
	check_eq(longest.collision_layer & LevelBuilder.LAYER_WORLD, LevelBuilder.LAYER_WORLD, "on the world layer")
	check(longest is Shelving, "and it is something that can be knocked over")
	var mesh: Mesh = (longest.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D).mesh
	check(mesh.get_surface_count() >= 6, "with shelves and books of several colours on it, got %d surfaces" % mesh.get_surface_count())


func test_books_upstairs_stores_in_the_cold() -> void:
	check(Furniture.shelf_mesh(2, "f3_servers") != Furniture.shelf_mesh(2, "f27_furnace"), "the cold store does not keep a library")
	check(Furniture.shelf_mesh(3, "f3_servers") == Furniture.shelf_mesh(3, "f8_archive"), "the same unit is built once and shared")


func test_pillars_have_a_base_and_are_still_the_same_box() -> void:
	check(Game.load_floor(2), "server room loads")
	await wait_physics(3)
	var pillar: StaticBody3D = Game.level.find_children("*Pillar*", "StaticBody3D", true, false)[0]
	var box: BoxShape3D = (pillar.get_child(0) as CollisionShape3D).shape
	check_eq(box.size, Vector3(Furniture.PILLAR_WIDTH, T.wall_height, Furniture.PILLAR_WIDTH), "collision unchanged")
	var mesh: Mesh = (pillar.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D).mesh
	check(mesh.get_aabb().size.x > Furniture.PILLAR_WIDTH + 0.2, "the stone base stands out past the shaft")
	check_eq(mesh.get_surface_count(), 2, "shaft and stone")
