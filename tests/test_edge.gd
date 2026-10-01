extends "res://tests/test_case.gd"
## Nobody walks out of the building. A glove sees to it.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_stepping_off_brings_out_the_glove() -> void:
	check(Game.load_level("f12_kitchen"), "a floor with windows loads")
	await wait_physics(3)
	var pane: GlassPane = get_tree().get_first_node_in_group(&"windows") as GlassPane
	check(pane != null, "there is a window")
	var d: LevelData = Game.data
	# Stand him in the void outside the wall.
	var here: Vector2i = d.cell_of(pane.global_position)
	var outward := Vector2i.ZERO
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if d.char_at(here + step) == " ":
			outward = step
	check(outward != Vector2i.ZERO, "and air on the other side of it")
	Game.player.global_position = d.cell_center(here + outward, 0.1)
	await wait_physics(2)
	check(get_tree().get_nodes_in_group(&"boxing_gloves").size() >= 1, "the glove comes out")
	check(Game.player.alive, "and he is not dead, he is embarrassed")


func test_the_glove_throws_him_back_inside_and_he_gets_up() -> void:
	check(Game.load_level("f12_kitchen"), "floor loads")
	await wait_physics(3)
	Game.player.punched_back(Vector3(1, 0, 0))
	check(Game.player.tumbling, "he is in the air")
	check(not Game.player.input_enabled, "and not in charge of it")
	for step: int in 300:
		await wait_physics(1)
		if not Game.player.tumbling:
			break
	check(not Game.player.tumbling, "he landed")
	check(Game.player.input_enabled, "and got up again")
	check(Game.player.alive, "alive throughout")
	check_eq(Game.player.camera.rotation.z, 0.0, "with the view back level")


func test_a_floor_with_no_void_never_gloves_anybody() -> void:
	check(Game.load_level("f1_lobby"), "the lobby loads")
	await wait_physics(3)
	for step: int in 30:
		await wait_physics(1)
	check_eq(get_tree().get_nodes_in_group(&"boxing_gloves").size(), 0, "nothing swings at him indoors")
