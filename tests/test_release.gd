extends "res://tests/test_case.gd"
## The containment release in the basement, and the liquid in the ducts.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	check(Game.load_level("f13_basement"), "the basement loads")
	await wait_physics(4)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func test_the_basement_has_a_release_and_tanks_with_things_in_them() -> void:
	var lever: ReleaseLever = get_tree().get_first_node_in_group(&"release_lever") as ReleaseLever
	check(lever != null, "the lever is on the wall")
	check(not lever.used, "and it has not been thrown")
	var whole: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"tanks"):
		if not (node as SpecimenTank).cracked:
			whole += 1
	check(whole >= 10, "with tanks still sealed (%d)" % whole)


func test_throwing_it_lets_everything_out() -> void:
	var lever: ReleaseLever = get_tree().get_first_node_in_group(&"release_lever") as ReleaseLever
	var before: int = Game.alive_enemies
	var out: int = lever.pull()
	check(lever.used, "it only works once")
	check(out >= 10, "a tank's worth each (%d)" % out)
	await wait_physics(3)
	check(Game.alive_enemies > before, "and they count: %d to %d" % [before, Game.alive_enemies])
	check_eq(lever.pull(), 0, "pulling it again does nothing")


func test_a_punch_throws_it_too() -> void:
	var lever: ReleaseLever = get_tree().get_first_node_in_group(&"release_lever") as ReleaseLever
	lever.on_punched(Game.player, lever.global_position)
	check(lever.used, "a punch is enough")


func test_the_liquid_can_get_into_a_duct() -> void:
	var beast: Beast = get_tree().get_first_node_in_group(&"bosses") as Beast
	if beast == null:
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			if node is Beast:
				beast = node
	check(beast != null, "the thing is down here")
	check_eq(beast.form, Beast.Form.LIQUID, "and it starts as a slick")
	# Flattened, it fits under a duct's roof.
	check(beast._capsule.height < VentDuct.HEIGHT, "it is low enough for the tunnel (%.2f)" % beast._capsule.height)
	var ducts: int = 0
	for y: int in Game.data.height:
		for x: int in Game.data.width:
			if Game.data.rows[y][x] == "v" or Game.data.rows[y][x] == "e":
				ducts += 1
	check(ducts > 0, "and there are ducts for it to use (%d cells)" % ducts)
	var target: Vector3 = beast._somewhere_to_hide()
	check(VentDuct.inside(Game.data, target), "the place it heads for is one of them")
