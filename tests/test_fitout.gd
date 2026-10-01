extends "res://tests/test_case.gd"
## What is on the shelves, and what the dudes are wearing, floor by floor.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_each_floor_keeps_the_right_things_on_its_shelves() -> void:
	check_eq(Furniture.shelf_kind("f3_servers"), &"books", "the tower reads")
	check_eq(Furniture.shelf_kind("f11_sewers"), &"cleaning", "the sewers keep mops")
	check_eq(Furniture.shelf_kind("f28_waterworks"), &"cleaning", "so does the waterworks")
	check_eq(Furniture.shelf_kind("f16_armoury"), &"store", "the armoury keeps stores")
	for station: String in ["f31_airlock", "f35_cargobay", "f40_bridge"]:
		check_eq(Furniture.shelf_kind(station), &"suits", "%s keeps suits, not books" % station)


func test_the_shelves_are_built_differently_for_each() -> void:
	var books: ArrayMesh = Furniture.shelf_mesh(3, "f3_servers")
	var suits: ArrayMesh = Furniture.shelf_mesh(3, "f31_airlock")
	var cleaning: ArrayMesh = Furniture.shelf_mesh(3, "f11_sewers")
	check(books != suits, "a bookcase is not a suit locker")
	check(suits != cleaning, "and a suit locker is not a mop cupboard")
	for mesh: ArrayMesh in [books, suits, cleaning]:
		check(mesh.get_surface_count() >= 2, "each one is built out of several materials")


func test_everybody_on_the_station_is_suited_and_helmeted() -> void:
	check(Game.load_level("f31_airlock"), "a station floor loads")
	await wait_physics(3)
	var seen: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node
		check(dude.wears_helmet, "%s has a helmet on" % dude.name)
		check_eq(dude.body_material, Mats.spacesuit(), "%s is in a suit" % dude.name)
		seen += 1
	check(seen >= 5, "and there are some of them (%d)" % seen)


func test_nobody_in_the_tower_is_wearing_one() -> void:
	check(Game.load_level("f3_servers"), "a tower floor loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		check(not (node as PinkDude).wears_helmet, "no helmets indoors")
