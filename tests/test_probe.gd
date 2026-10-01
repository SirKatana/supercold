extends "res://tests/test_case.gd"


func test_thirteen_to_fourteen() -> void:
	Game.god_mode = true
	check(Game.load_level("f13_basement"), "basement loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	for node: Node in get_tree().get_nodes_in_group(&"lurkers"):
		(node as VentLurker).take_damage(9)
	await wait_physics(6)
	print("PROBE state=", Game.state, " alive=", Game.alive_enemies, " clear=", Game.is_floor_clear())
	var lift: Elevator = get_tree().get_first_node_in_group(&"elevator") as Elevator
	print("PROBE lift=", lift, " present=", (lift.present if lift != null else "n/a"))
	if lift != null:
		lift.press()
		Game.player.global_position = lift.global_position
		for step: int in 600:
			await wait_physics(1)
			if Game.level_name != "f13_basement":
				break
		print("PROBE after ride level=", Game.level_name, " state=", Game.state,
			" glitch=", Game.glitch, " player=", (Game.player.global_position if Game.player != null else Vector3.ZERO))
		for step: int in 400:
			await wait_physics(1)
		for node: Node in get_tree().get_nodes_in_group(&"arrival"):
			var cab: Elevator = node
			print("PROBE ARRIVAL phase=", cab.phase, " door=", cab.door_open, " present=", cab.present,
				" visible=", cab.visible, " announced=", cab._announced, " timer=", cab._timer)
		print("PROBE music=", Sfx.music_playing() if Sfx.has_method("music_playing") else "?",
			" player_inside_cab=", Game.player.global_position)
	Game.god_mode = false
	check(true, "printed")
