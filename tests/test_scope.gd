extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()


func after_each() -> void:
	Input.action_release(&"secondary")
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _give(gun: Gun) -> void:
	Game.entities_root(self).add_child(gun)
	Game.player.hands.pick_up(gun)


func test_holding_right_click_with_the_sniper_zooms_in_and_releasing_zooms_out() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var rifle: SniperRifle = SniperRifle.create()
	_give(rifle)
	check(rifle.has_scope, "the sniper rifle has a scope")
	var normal_fov: float = Game.player.camera.fov
	Input.action_press(&"secondary")
	await wait_frames(40)
	check(Game.player.fx.scope_amount > 0.95, "fully scoped")
	check(Game.player.camera.fov < normal_fov * 0.3, "zoomed right in (%.0f from %.0f)" % [Game.player.camera.fov, normal_fov])
	check(Game.player.hands.held == rifle, "right click did not throw it")
	check(not Game.player.hands.visible, "the rifle is out of the way of the lens")
	Input.action_release(&"secondary")
	await wait_frames(40)
	check_near(Game.player.camera.fov, normal_fov, 0.5, "back to normal")
	check(Game.player.hands.visible, "hands back")


func test_other_guns_do_not_scope_and_right_click_still_throws_them() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var pistol: Pistol = Pistol.create()
	_give(pistol)
	Game.player.hands.secondary()
	check(Game.player.hands.held == null, "a pistol is thrown by right click as before")
	check(Game.player.fx.scope_amount < 0.01, "and nothing zoomed")


func test_q_throws_the_sniper() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var rifle: SniperRifle = SniperRifle.create()
	_give(rifle)
	check(InputMap.has_action(&"throw_item"), "Q is bound")
	Input.action_press(&"throw_item")
	await wait_physics(2)
	Input.action_release(&"throw_item")
	check(Game.player.hands.held == null, "Q threw it")
	check_eq(rifle.state, Pickup.State.FLYING, "it is in the air")


func test_scoped_shot_goes_exactly_where_the_reticle_points() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var rifle: SniperRifle = SniperRifle.create()
	_give(rifle)
	Game.player.fx.scope_amount = 1.0
	var shot: Array[Vector3] = Game.player.hands._shot_from_muzzle(rifle)
	check(shot[1].is_equal_approx(Game.player.aim_direction()), "direction is the camera's, not the muzzle's")


func test_scope_slows_the_mouse() -> void:
	check(T.scope_fov < 20.0, "a real zoom")
	check(T.scope_fov / 85.0 < 0.25, "so the mouse is at least four times slower when scoped")
