extends "res://tests/test_case.gd"
## Fighting in a duct: the boot works in there, and the camera stays in the tunnel.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.lurker_always = true
	check(Game.load_level("f11_sewers"), "the sewers load")
	await wait_physics(4)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.lurker_always = false
	Game.god_mode = false
	if Game.player != null and is_instance_valid(Game.player):
		Game.player.set_third_person(false)
	Game.unload_level()


func _a_duct_cell() -> Vector2i:
	for y: int in Game.data.height:
		for x: int in Game.data.width:
			if Game.data.rows[y][x] == "v":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_you_can_kick_while_you_are_crawling() -> void:
	var cell: Vector2i = _a_duct_cell()
	check(cell.x >= 0, "the floor has ducts")
	Game.player.use_a_duct()
	Game.player.global_position = Game.data.cell_center(cell, 0.05)
	await wait_physics(4)
	check(Game.player.crawling, "he is on his belly")
	check(Game.player.hands.kick(), "and the boot still goes in")
	check(Game.player.hands.kick_cooldown_left > 0.0, "with the usual wait after it")


func test_the_third_person_camera_stays_in_the_tunnel() -> void:
	var cell: Vector2i = _a_duct_cell()
	Game.player.use_a_duct()
	Game.player.global_position = Game.data.cell_center(cell, 0.05)
	Game.player.set_third_person(true)
	await wait_physics(20)
	var out: float = Game.player.camera.position.length()
	check(out <= T.tps_crawl_boom + 0.01, "the boom is tucked in (%.2f m)" % out)
	check(Game.player.camera.global_position.y < VentDuct.HEIGHT + 0.2,
		"and the camera is under the duct roof (%.2f)" % Game.player.camera.global_position.y)
