extends "res://tests/test_case.gd"
## T swaps between his eyes and over his shoulder.


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	if Game.player != null and is_instance_valid(Game.player):
		Game.player.set_third_person(false)
	Game.god_mode = false
	Game.unload_level()


func test_third_person_moves_the_camera_back_and_shows_the_body() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var me: Player = Game.player
	# Out of the arrival cabin first: in it there is a wall a foot behind his head, and the
	# boom is supposed to give way to that.
	me.global_position += -me.global_transform.basis.z * 4.0
	await wait_physics(4)
	check(not me.third_person, "first person to start with")
	check_eq(me.camera.position, Vector3.ZERO, "and the camera is in his head")
	me.set_third_person(true)
	await wait_physics(20)
	check(me.third_person, "switched")
	check(me.camera.position.length() > 1.0, "the camera is behind him (%.2f m)" % me.camera.position.length())
	check(me.camera.position.z > 0.0, "behind, not in front")
	# The arms go, but whatever is in them stays: it moves into the body's own hand.
	check(not me.hands._arm_r.visible, "the first-person arms are put away")
	check(not me.hands._arm_l.visible, "both of them")
	me.set_third_person(false)
	await wait_physics(2)
	check_eq(me.camera.position, Vector3.ZERO, "and back into his head again")


func test_shots_still_leave_from_his_head_not_from_the_camera() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var me: Player = Game.player
	me.set_third_person(true)
	await wait_physics(20)
	check(me.aim_origin().distance_to(me.head.global_position) < 0.01,
		"aiming from the head, not from a metre behind him")
	check(me.aim_direction().dot(-me.head.global_transform.basis.z) > 0.999, "and straight ahead")


func test_the_camera_comes_in_when_there_is_a_wall_behind_him() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var me: Player = Game.player
	me.global_position += -me.global_transform.basis.z * 4.0
	await wait_physics(4)
	me.set_third_person(true)
	await wait_physics(20)
	var open_boom: float = me.camera.position.length()
	check(open_boom > 1.0, "it is well back in the open (%.2f m)" % open_boom)
	# Back him into a corner: the boom has to give way rather than go through the wall.
	me.global_position = Game.data.cell_center(Vector2i(1, 1), 0.05)
	me.rotation.y = 0.0
	await wait_physics(20)
	check(me.camera.position.length() <= open_boom + 0.01, "it never goes further than it should")
