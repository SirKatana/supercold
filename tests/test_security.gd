extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.fast_elevators = true
	Game.start_run_state_for_tests()


func after_each() -> void:
	for action: StringName in [&"move_forward"]:
		Input.action_release(action)
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.start_run_state_for_tests()
	Game.unload_level()


func _exit_lift() -> Elevator:
	return get_tree().get_first_node_in_group(&"elevator") as Elevator


## Rides from floor 2 to floor 3 holding `item`.
func _ride_up_holding(item: Pickup) -> void:
	check(Game.load_floor(1), "offices load")
	await wait_physics(2)
	if item != null:
		Game.entities_root(self).add_child(item)
		Game.player.hands.pick_up(item)
	Game.next_floor()
	await wait_physics(3)
	check_eq(Game.level_name, "f3_servers", "arrived on the next floor")


# ---------------------------------------------------------------- the lift that is not there

func test_exit_lift_is_absent_until_every_enemy_is_dead() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var lift: Elevator = _exit_lift()
	check(not lift.present and not lift.visible, "no lift while enemies live")
	var space: PhysicsDirectSpaceState3D = lift.get_world_3d().direct_space_state
	var through := PhysicsRayQueryParameters3D.create(lift.global_position + Vector3(-1.6, 1.2, 0), lift.global_position + Vector3(1.6, 1.2, 0), 1 | 32)
	check(space.intersect_ray(through).is_empty(), "nothing solid where it will be: no walls, no doors, no button")
	Game.player.global_position = lift.global_position + Vector3(0, 0.05, 0)
	await wait_physics(10)
	check_eq(Game.state, Game.State.PLAYING, "standing on the spot does nothing")
	Game.player.global_position = Game.data.cell_center(Vector2i(2, 2), 0.05)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	for node: Node in get_tree().get_nodes_in_group(&"lurkers"):
		(node as VentLurker).take_damage(9)
	await wait_physics(10)
	check(lift.present and lift.visible, "last enemy dead: the lift arrives")
	check_eq(lift.phase, Elevator.Phase.READY, "and waits for its button")
	check(not space.intersect_ray(through).is_empty(), "solid now")
	check(Sfx.history.has(&"ding"), "with a ding")


func test_a_new_floor_does_not_inherit_the_cleared_lift() -> void:
	check(Game.load_floor(0), "lobby loads")
	await wait_physics(2)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	for node: Node in get_tree().get_nodes_in_group(&"lurkers"):
		(node as VentLurker).take_damage(9)
	await wait_physics(3)
	check_eq(Game.state, Game.State.CLEARED, "lobby cleared")
	Game.next_floor()
	await wait_physics(3)
	check(not _exit_lift().present, "the next floor's exit lift is not there yet")


func test_player_standing_where_the_lift_lands_is_not_shut_in() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var lift: Elevator = _exit_lift()
	Game.player.global_position = lift.global_position + Vector3(0, 0.05, 0)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	for node: Node in get_tree().get_nodes_in_group(&"lurkers"):
		(node as VentLurker).take_damage(9)
	await wait_physics(2)
	check(lift.phase != Elevator.Phase.READY or lift.door_open > 0.0, "doors opened for him rather than wait for a button he cannot reach")


# ---------------------------------------------------------------- carrying things up

func test_what_you_hold_rides_up_with_you() -> void:
	var pistol: Pistol = Pistol.create(3)
	await _ride_up_holding(pistol)
	var held: Pickup = Game.player.hands.held
	check(held is Pistol, "still holding a pistol on the next floor")
	check_eq((held as Pistol).ammo, 3, "with the rounds it had")
	check(held.contraband, "and security will want it")


func test_harmless_things_ride_up_too_and_nobody_cares() -> void:
	await _ride_up_holding(Throwable.create(&"mug"))
	check(Game.player.hands.held is Throwable, "the mug came along")
	check(Game.guard == null, "no guard for a mug")


func test_empty_hands_mean_no_guard() -> void:
	await _ride_up_holding(null)
	check(Game.guard == null, "nobody waiting")
	check(Game.player.hands.held == null, "nothing in hand")


func test_security_knows_a_weapon_from_a_mug() -> void:
	for weapon: Pickup in [Pistol.create(), Rifle.create(), Knife.create(), Ram.create(), FreezeBomb.create(), FartGrenade.create()]:
		check(weapon.is_weapon(), "%s is a weapon" % weapon.name)
		weapon.free()
	for harmless: Pickup in [Throwable.create(&"mug"), WaterBucket.create(), GasBarrel.create()]:
		check(not harmless.is_weapon(), "%s is not" % harmless.name)
		harmless.free()


# ---------------------------------------------------------------- the checkpoint

func test_guard_is_posted_outside_the_lift_facing_it() -> void:
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	check(guard != null and is_instance_valid(guard), "a guard is waiting")
	var lift: Transform3D = LevelBuilder.elevator_transform(Game.data, Game.data.player_start)
	var out: Vector3 = -lift.basis.z
	var along: float = (guard.global_position - lift.origin).dot(out)
	check(along > 2.0 and along < 9.0, "a few metres out from the doors (%.1f m)" % along)
	check((-guard.global_transform.basis.z).dot(-out) > 0.9, "facing the lift")
	check(guard.skin.has_sunglasses(), "sunglasses, naturally")
	check_eq(guard.skin.material, Mats.security_suit(), "in a dark security suit, not pink")
	check(not guard.is_in_group(&"enemies"), "and he does not count toward clearing the floor")
	check_eq(Game.alive_enemies, Game.data.initial_enemy_count(), "enemy count unchanged")


func test_throwing_it_to_him_is_how_you_hand_it_over() -> void:
	await _ride_up_holding(Rifle.create())
	var guard: SecurityGuard = Game.guard
	var state: Dictionary = {"taken": &"", "at": Vector3.ZERO}
	guard.weapon_taken.connect(func(kind: StringName) -> void:
		state["taken"] = kind
		state["at"] = guard.global_position)
	var post: Vector3 = guard.global_position
	Game.player.global_position = guard.global_position - guard.global_transform.basis.z * 3.4
	Game.player.look_at(guard.global_position + Vector3(0, 0.0, 0))
	await wait_physics(3)
	TimeManager.override_scale = 1.0
	Game.player.hands.throw_held()
	await wait_physics(40)
	check_eq(state["taken"], &"rifle", "he caught the rifle")
	check(state["at"].distance_to(post) < 0.2, "out of the air, without leaving his post")
	check(Game.player.hands.held == null, "hands are empty")
	check_eq(guard.voice.history.has(HelperVoice.line(&"guard_thanks")), true, "with a thank you")
	check(Game.player.alive, "nobody got shot")
	for i: int in 500:
		await wait_physics(1)
		if not is_instance_valid(guard):
			break
	check(not is_instance_valid(guard), "he walked into the lift and is gone")


func test_standing_next_to_him_is_not_enough() -> void:
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	Game.player.global_position = guard.global_position - guard.global_transform.basis.z * 1.3
	await wait_physics(20)
	check(Game.player.hands.held != null, "he does not take it out of your hand: you throw it")
	check_eq(guard.taken, 0, "nothing taken")


func test_a_weapon_dropped_out_of_reach_he_walks_to() -> void:
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	var post: Vector3 = guard.global_position
	var gun: Pickup = Game.player.hands.held
	Game.player.hands.throw_held()
	gun.global_position = post - guard.global_transform.basis.z * 3.6 + Vector3(0, 0.3, 0)
	gun.velocity = Vector3.ZERO
	await wait_physics(10)
	check_eq(guard.mode, SecurityGuard.Mode.FETCHING, "he goes to get it")
	check_eq(guard.taken, 0, "and has not got it yet: no reaching across the room")
	for i: int in 300:
		await wait_physics(1)
		if guard.taken > 0:
			break
	check(guard.taken >= 1, "he picked it up off the floor")
	check(guard.global_position.distance_to(post) > 1.0, "by walking over to it")
	check(Game.player.alive, "unharmed")


func test_running_away_armed_does_not_work_he_chases() -> void:
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	var post: Vector3 = guard.global_position
	guard._open_fire()
	TimeManager.override_scale = 1.0
	# Somewhere far off on this floor: the exit end.
	Game.player.global_position = Game.data.cell_center(Game.data.front_cell(Game.data.exit_cell), 0.05)
	var start: float = guard.global_position.distance_to(Game.player.global_position)
	await wait_physics(90)
	check(guard.global_position.distance_to(post) > 2.0, "he left his post")
	check(guard.global_position.distance_to(Game.player.global_position) < start - 2.0, "and is closing on the player")
	check(T.guard_chase_speed > T.walk_speed, "faster than the player can walk")


func test_walking_past_him_armed_gets_you_shot() -> void:
	Game.god_mode = false
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	var lift: Transform3D = LevelBuilder.elevator_transform(Game.data, Game.data.player_start)
	var out: Vector3 = -lift.basis.z
	var side: Vector3 = lift.basis.x
	# Round him, well out of arm's reach, and on past.
	Game.player.global_position = guard.global_position + out * 3.0 + side * 0.0 + Vector3(0, 0.05, 0)
	var fired: Dictionary = {"yes": false}
	guard.opened_fire.connect(func() -> void: fired["yes"] = true)
	for i: int in 400:
		await wait_physics(1)
		if not Game.player.alive:
			break
	check(fired["yes"], "he opened fire")
	check_eq(guard.voice.history.has(HelperVoice.line(&"guard_stop")), true, "after shouting stop")
	check(not Game.player.alive, "and he does not miss")


func test_dropping_it_under_fire_makes_him_stop() -> void:
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	var out: Vector3 = -LevelBuilder.elevator_transform(Game.data, Game.data.player_start).basis.z
	Game.player.global_position = guard.global_position + out * 4.0 + Vector3(0, 0.05, 0)
	await wait_physics(20)
	check_eq(guard.mode, SecurityGuard.Mode.FIRING, "shooting")
	Game.player.hands.throw_held()
	await wait_physics(40)
	check(guard.mode != SecurityGuard.Mode.FIRING, "he stops once it is out of your hand")


func test_firing_the_weapon_at_the_checkpoint_counts_as_moving_on() -> void:
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	await wait_physics(2)
	Game.player.hands.primary()
	check_eq(guard.mode, SecurityGuard.Mode.FIRING, "you do not fire a weapon you were told to hand over")


func test_nothing_the_player_has_hurts_him() -> void:
	await _ride_up_holding(Pistol.create())
	var guard: SecurityGuard = Game.guard
	for i: int in 10:
		guard.on_bullet_hit(null, guard.global_position + Vector3.UP, Vector3.LEFT)
	check(is_instance_valid(guard), "armoured")


func test_dying_at_the_checkpoint_does_not_bring_the_guard_back() -> void:
	Game.god_mode = false
	await _ride_up_holding(Pistol.create())
	check(Game.guard != null, "guard on first arrival")
	Game.player.die()
	for i: int in 400:
		await wait_physics(1)
		if Game.state == Game.State.PLAYING and Game.player != null and Game.player.alive:
			break
	check(Game.guard == null, "the retry starts clean: no weapon, no guard")
	check(Game.player.hands.held == null, "empty hands")
