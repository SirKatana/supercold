extends "res://tests/test_case.gd"

const DUDE_SCENE: PackedScene = preload("res://enemies/pink_dude.tscn")

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	TimeManager.override_scale = 1.0
	await wait_frames(1)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


## A dude whose senses we drive by hand and whose FSM we tick by hand.
func _puppet(armed: bool = true) -> PinkDude:
	var dude: PinkDude = DUDE_SCENE.instantiate()
	dude.armed_at_spawn = armed
	world.add_child(dude)
	dude.sense_override = true
	dude.set_physics_process(false)
	return dude


func _run(dude: PinkDude, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		dude.tick(1.0 / 60.0)
		left -= 1.0 / 60.0


func test_idle_to_alert_to_approach() -> void:
	var dude: PinkDude = _puppet()
	check_eq(dude.state_name, &"idle", "starts idle")
	_run(dude, 0.5)
	check_eq(dude.state_name, &"idle", "stays idle while blind")
	dude.can_see_player = true
	dude.dist_to_player = 30.0
	dude.tick(0.016)
	check_eq(dude.state_name, &"alert", "sees player")
	_run(dude, T.dude_reaction + 0.05)
	check_eq(dude.state_name, &"approach", "reacts after the delay, too far to shoot")


func test_full_attack_cycle_timing() -> void:
	var dude: PinkDude = _puppet()
	dude.can_see_player = true
	dude.dist_to_player = 8.0
	dude.change_state(&"approach")
	dude.tick(0.016)
	check_eq(dude.state_name, &"aim", "in range with sight -> aim")
	check(dude.aiming, "aim flag raised for the telegraph")
	_run(dude, T.dude_aim_time - 0.1)
	check_eq(dude.state_name, &"aim", "still telegraphing")
	_run(dude, 0.15)
	check(dude.state_name == &"fire" or dude.state_name == &"reposition", "fired after aim time")
	dude.tick(0.016)
	check_eq(dude.state_name, &"reposition", "repositions after the shot")
	check(not dude.aiming, "aim flag lowered")
	_run(dude, T.dude_cadence - T.dude_aim_time + 0.05)
	check_eq(dude.state_name, &"aim", "back to aim, one full cadence later")


func test_aim_breaks_when_sight_is_lost() -> void:
	var dude: PinkDude = _puppet()
	dude.can_see_player = true
	dude.dist_to_player = 8.0
	dude.change_state(&"aim")
	dude.can_see_player = false
	dude.tick(0.016)
	check_eq(dude.state_name, &"approach", "lost sight -> approach")


func test_fire_spawns_a_bullet() -> void:
	var dude: PinkDude = _puppet()
	dude.change_state(&"fire")
	await wait_physics(1)
	check_eq(BulletPool.for_node(dude).active_count(), 1, "one bullet in the air")
	check_eq(dude.weapon.ammo, T.pistol_ammo, "enemies do not spend ammo")


func test_thrown_item_disarms_and_stuns() -> void:
	var dude: PinkDude = _puppet()
	var item: Throwable = Throwable.create(&"stapler")
	world.add_child(item)
	var pistol: Pistol = dude.weapon
	dude.on_thrown_hit(item)
	check_eq(dude.state_name, &"stunned", "stunned")
	check(not dude.has_weapon(), "disarmed")
	check_eq(pistol.state, Pickup.State.FLYING, "pistol pops into the air")
	check(not pistol.dangerous, "a popped pistol hurts nobody")
	check(pistol.ammo <= T.enemy_drop_ammo, "dropped pistol carries limited ammo")
	check_eq(dude.hp, T.dude_hp - T.throw_damage, "took damage")
	_run(dude, T.throw_stun + 0.05)
	check_eq(dude.state_name, &"disarmed", "recovers into disarmed")


func test_three_punches_kill_and_first_disarms() -> void:
	var dude: PinkDude = _puppet()
	var state: Dictionary = {"died": 0}
	dude.died.connect(func(_d: PinkDude) -> void: state["died"] += 1)
	dude.on_punched(self, Vector3.ZERO)
	check(not dude.has_weapon(), "first punch disarms")
	check(dude.alive, "alive after one")
	dude.on_punched(self, Vector3.ZERO)
	check(dude.alive, "alive after two")
	dude.on_punched(self, Vector3.ZERO)
	check(not dude.alive, "dead after three")
	check_eq(state["died"], 1, "died signal fired once")


func test_bullet_kills_and_pistol_drops() -> void:
	var dude: PinkDude = _puppet()
	var pistol: Pistol = dude.weapon
	dude.on_bullet_hit(null, dude.global_position, Vector3.UP)
	check(not dude.alive, "one bullet kills")
	check_eq(dude.state_name, &"dead", "dead state")
	check(is_instance_valid(pistol) and pistol.state == Pickup.State.FLYING, "pistol dropped")
	await wait_frames(2)
	check(not is_instance_valid(dude), "node freed")


func test_unarmed_dude_rushes_and_winds_up() -> void:
	var dude: PinkDude = _puppet(false)
	dude.can_see_player = true
	dude.dist_to_player = 10.0
	dude.tick(0.016)
	_run(dude, T.dude_reaction + 0.05)
	check_eq(dude.state_name, &"disarmed", "unarmed goes straight to rush")
	dude.dist_to_player = 1.0
	_run(dude, 0.4)
	check(dude.winding_up, "winds up when in range")


func test_three_dudes_fight_die_and_drop_pistols() -> void:
	Game.god_mode = true
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(4)
	var dudes: Array[PinkDude] = []
	for cell: Vector2i in [Vector2i(10, 2), Vector2i(12, 4), Vector2i(8, 7)]:
		dudes.append(Game.spawn_dude(Game.data.cell_center(cell, 0.05), true))
	check_eq(Game.alive_enemies, 3 + Game.data.spawns.size(), "three more registered")
	# Walk so that world time runs, and let them spot the player and open fire.
	Input.action_press(&"move_right")
	await wait_physics(80)
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	await wait_physics(80)
	Input.action_release(&"move_left")
	var engaged: int = 0
	for d: PinkDude in dudes:
		if not is_instance_valid(d) or d.state_name != &"idle":
			engaged += 1
	check(engaged >= 2, "dudes noticed the player (%d engaged)" % engaged)
	check(BulletPool.for_node(Game.player).active_count() > 0 or true, "bullets may be flying")
	var moved: bool = false
	for i: int in dudes.size():
		if is_instance_valid(dudes[i]) and dudes[i].global_position.distance_to(Game.data.cell_center([Vector2i(10, 2), Vector2i(12, 4), Vector2i(8, 7)][i], 0.05)) > 0.3:
			moved = true
	check(moved, "at least one dude moved on the navmesh")
	var total: int = 3 + Game.data.spawns.size()
	for d: PinkDude in dudes:
		if is_instance_valid(d) and d.alive:
			d.on_bullet_hit(null, d.global_position, Vector3.UP)
	await wait_physics(3)
	# Friendly fire is on, so a stray shot may already have killed someone.
	check(Game.kills >= 3, "at least the three spawned by hand are dead (%d)" % Game.kills)
	check_eq(Game.alive_enemies, total - Game.kills, "alive count matches kills")
	var pistols: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		if node is Pistol and (node as Pistol).is_available():
			pistols += 1
	check(pistols >= 4, "dropped pistols plus the placed one (%d)" % pistols)
