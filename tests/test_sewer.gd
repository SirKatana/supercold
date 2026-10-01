extends "res://tests/test_case.gd"
## The sewer channel: a half-pipe of green water with bodies going past in it.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_the_sewers_have_a_channel_and_the_kitchen_does_not() -> void:
	var sewers: LevelData = LevelParser.load_level("f11_sewers")
	check(sewers.errors.is_empty(), "f11 parses: %s" % ", ".join(sewers.errors))
	check(sewers.channel_cells.size() >= 20, "a long channel (%d cells)" % sewers.channel_cells.size())
	check_eq(LevelParser.load_level("f12_kitchen").channel_cells.size(), 0, "no channel in the kitchen")


func test_the_channel_is_a_trough_with_water_and_bodies_in_it() -> void:
	check(Game.load_level("f11_sewers"), "the sewers load")
	await wait_physics(3)
	var channels: Array[Node] = get_tree().get_nodes_in_group(&"sewer_channel")
	check(channels.size() >= 1, "the channel is built (%d)" % channels.size())
	var bodies: Array[Node] = get_tree().get_nodes_in_group(&"sewer_bodies")
	check(bodies.size() >= 2, "there is something in it (%d)" % bodies.size())
	for node: Node in bodies:
		var body: SewerBody = node
		check(body.global_position.y < 0.0, "floating below the deck (%.2f)" % body.global_position.y)
		check(body.global_position.y > -SewerChannel.DEPTH, "but not under the invert")


func test_the_bodies_drift_and_come_round_again() -> void:
	check(Game.load_level("f11_sewers"), "the sewers load")
	await wait_physics(3)
	var body: SewerBody = get_tree().get_first_node_in_group(&"sewer_bodies") as SewerBody
	check(body != null, "one of them is here")
	TimeManager.override_scale = 1.0
	var started: float = body.offset
	await wait_physics(60)
	check(body.offset > started, "it moved down the channel (%.2f to %.2f)" % [started, body.offset])
	# Far enough along and it starts again at the top rather than sailing out of the level.
	body.offset = body.run_length
	await wait_physics(2)
	check(body.offset < 0.0, "and comes round again")
	TimeManager.override_scale = -1.0


func test_the_floor_is_cut_away_over_the_channel() -> void:
	check(Game.load_level("f11_sewers"), "the sewers load")
	await wait_physics(3)
	var d: LevelData = Game.data
	var cell: Vector2i = d.channel_cells[d.channel_cells.size() / 2]
	var over: Vector3 = d.cell_center(cell, 1.0)
	var space: PhysicsDirectSpaceState3D = Game.player.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * 3.0, 1)
	var hit: Dictionary = space.intersect_ray(down)
	check(not hit.is_empty(), "there is a bottom to it")
	check(hit["position"].y < -0.4, "well below the deck (%.2f)" % hit["position"].y)
