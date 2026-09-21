extends "res://tests/test_case.gd"
## The web build does not draw a dude the camera cannot see. He must still be there.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()
	PinkDude.cull_unseen = true


func after_each() -> void:
	PinkDude.cull_unseen = OS.has_feature("web")
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _dudes() -> Array:
	return get_tree().get_nodes_in_group(&"enemies")


func test_a_dude_behind_walls_is_not_drawn_but_still_lives() -> void:
	check(Game.load_floor(1), "offices load")
	for node: Node in _dudes():
		(node as PinkDude).sense_override = true
	await wait_physics(12)
	var hidden: Array = _dudes().filter(func(d: PinkDude) -> bool: return not d.drawn)
	check(hidden.size() >= 3, "most of the floor is behind walls from the lift, got %d hidden" % hidden.size())
	var dude: PinkDude = hidden[0]
	check(not dude.skin.visible, "his body is not drawn")
	check(dude.alive and not dude.joints.is_empty(), "but he is alive and posed")
	await wait_physics(30)
	var feet: Vector3 = dude.global_position
	var alive_before: int = Game.alive_enemies
	dude.die()
	check_eq(Game.alive_enemies, alive_before - 1, "and he dies like anyone else")
	var pelvis: Vector3 = dude.joints[Humanoid.index_of(&"pelvis")]
	check(Vector2(pelvis.x - feet.x, pelvis.z - feet.z).length() < 0.4, "his body falls where he stood, not where he was last drawn")


func test_he_is_drawn_again_the_moment_the_camera_can_see_him() -> void:
	check(Game.load_floor(1), "offices load")
	for node: Node in _dudes():
		(node as PinkDude).sense_override = true
	await wait_physics(12)
	var hidden: Array = _dudes().filter(func(d: PinkDude) -> bool: return not d.drawn)
	var dude: PinkDude = hidden[0]
	Game.player.global_position = dude.global_position + Vector3(0.0, 0.05, 1.5)
	await wait_physics(8)
	check(dude.drawn and dude.skin.visible, "standing next to him, he is drawn")
	check(dude.hand_anchor.visible, "gun and all")


func test_the_desktop_build_draws_everyone() -> void:
	PinkDude.cull_unseen = false
	check(Game.load_floor(1), "offices load")
	await wait_physics(12)
	check(_dudes().all(func(d: PinkDude) -> bool: return d.drawn and d.skin.visible), "nobody is hidden")
