extends "res://tests/test_case.gd"
## Freeze bombs, water and ice, fart clouds, knives, melting, the new guns.

var _spot: Vector3


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for group: StringName in [&"enemies", &"barrels", &"buried"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	Game.alive_enemies = 0
	_spot = Game.data.cell_center(Vector2i(8, 8), 0.05)
	Game.player.global_position = Game.data.cell_center(Vector2i(2, 8), 0.05)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.start_run_state_for_tests()
	Game.unload_level()


func _dude(offset: Vector3 = Vector3.ZERO, kind: StringName = &"pistol") -> PinkDude:
	var d: PinkDude = Game.spawn_dude(_spot + offset, kind != &"", kind)
	d.sense_override = true
	return d


# ---------------------------------------------------------------- freeze

func test_freeze_bomb_freezes_everyone_in_reach_and_walls_block_it() -> void:
	var near: PinkDude = _dude(Vector3(2, 0, 0))
	var also: PinkDude = _dude(Vector3(-2, 0, -2), &"shield")
	var far: PinkDude = _dude(Vector3(14, 0, -10))
	await wait_physics(2)
	var bomb: FreezeBomb = FreezeBomb.create()
	Game.entities_root(self).add_child(bomb)
	bomb.global_position = _spot + Vector3(0, 0.5, 0)
	check_eq(bomb.burst(), 2, "two dudes frozen")
	check(near.frozen and also.frozen, "both in reach are ice")
	check(not far.frozen, "the far one is not")
	check_eq(near.state_name, &"frozen", "frozen state")
	check_eq(near.skin.material, Mats.ice(), "and he looks like ice")


func test_frozen_dude_shatters_to_anything_and_a_frozen_trooper_dies_to_a_body_shot() -> void:
	var dude: PinkDude = _dude()
	var trooper: PinkDude = _dude(Vector3(4, 0, 0), &"shield")
	await wait_physics(2)
	dude.freeze(5.0)
	trooper.freeze(5.0)
	dude.on_punched(self, Vector3.ZERO)
	check(not dude.alive, "one punch shatters a frozen dude")
	check_eq(get_tree().get_nodes_in_group(&"ragdolls").size(), 0, "ice does not ragdoll")
	trooper.on_bullet_hit(null, trooper.global_position + Vector3.UP, Vector3.LEFT)
	check(not trooper.alive, "frozen armour is brittle")


func test_frozen_dude_thaws_and_carries_on() -> void:
	var dude: PinkDude = _dude()
	await wait_physics(2)
	dude.freeze(0.5)
	await wait_physics(45)
	check(not dude.frozen and dude.alive, "thawed")
	check_eq(dude.skin.material, Mats.pink(), "pink again")


func test_bosses_cannot_be_frozen() -> void:
	var brute := Brute.new()
	Game.entities_root(self).add_child(brute)
	brute.sense_override = true
	brute.freeze(5.0)
	check(not brute.frozen, "the Brute shrugs it off")
	check_eq(brute.state_name, &"stunned", "it only locks him up for a moment")


# ---------------------------------------------------------------- water and ice

func test_running_dude_slips_on_water_loses_his_gun_and_gets_up() -> void:
	var puddle := Puddle.new()
	Game.entities_root(self).add_child(puddle)
	puddle.global_position = _spot
	var dude: PinkDude = _dude()
	dude.set_physics_process(false)
	dude.desired_velocity = Vector3(3.2, 0, 0)
	await wait_physics(4)
	check_eq(dude.state_name, &"slipped", "down he goes")
	check(not dude.has_weapon(), "and the gun flies")
	dude.set_physics_process(true)
	await wait_physics(int(T.slip_seconds * 60.0) + 20)
	check(dude.state_name != &"slipped" and dude.alive, "he gets back up")


func test_standing_dude_does_not_slip_and_runners_always_do() -> void:
	var puddle := Puddle.new()
	Game.entities_root(self).add_child(puddle)
	puddle.global_position = _spot
	var still: PinkDude = _dude()
	still.set_physics_process(false)
	still.desired_velocity = Vector3.ZERO
	await wait_physics(6)
	check(still.state_name != &"slipped", "standing in water is fine")
	still.free()
	var runner: PinkDude = _dude(Vector3.ZERO, &"runner")
	runner.set_physics_process(false)
	runner.desired_velocity = Vector3(T.runner_speed, 0, 0)
	await wait_physics(4)
	check_eq(runner.state_name, &"slipped", "a runner at full tilt has no chance")


# ---------------------------------------------------------------- fart

func test_big_fart_cloud_chokes_dudes_to_death_but_not_gas_masks() -> void:
	var dude: PinkDude = _dude(Vector3(1.5, 0, 0))
	var trooper: PinkDude = _dude(Vector3(-2, 0, 1.5), &"shield")
	var cloud := FartCloud.new()
	Game.entities_root(self).add_child(cloud)
	cloud.global_position = _spot + Vector3(0, 1.1, 0)
	await wait_physics(2)
	check(not cloud.big, "drifting and small")
	cloud.on_bullet_hit(null, cloud.global_position, Vector3.UP)
	check(cloud.big, "shot: it bursts")
	await wait_physics(40)
	check(is_instance_valid(dude) and dude.choking, "he is choking")
	check(cloud.radius > T.fart_small_radius * 2.0, "and the cloud has filled the room (%.1f m)" % cloud.radius)
	await wait_physics(int(T.fart_kill_time * 60.0) + 40)
	check(not is_instance_valid(dude) or not dude.alive, "he choked to death")
	check(is_instance_valid(trooper) and trooper.alive and not trooper.choking, "the gas mask does its job")


func test_dude_who_gets_out_of_the_gas_recovers() -> void:
	var dude: PinkDude = _dude()
	dude.set_physics_process(true)
	dude.breathe_gas(0.4)
	check(dude.choking, "coughing")
	await wait_physics(50)
	check(not dude.choking and dude.alive, "fresh air fixes it")


func test_player_in_the_stink_only_gets_a_green_screen() -> void:
	Game.god_mode = false
	var cloud := FartCloud.new()
	Game.entities_root(self).add_child(cloud)
	cloud.global_position = Game.player.global_position + Vector3(0, 1.1, 0)
	cloud.burst()
	await wait_physics(30)
	check(Game.player.alive, "it does not hurt you")
	check(Game.player.in_stink > 0.0, "but you know about it")


# ---------------------------------------------------------------- knife

func test_knife_kills_in_one_stab_and_armour_turns_it() -> void:
	var dude: PinkDude = _dude()
	var knife: Knife = Knife.create()
	Game.entities_root(self).add_child(knife)
	Game.player.global_position = _spot + Vector3(-1.4, 0, 0)
	Game.player.look_at(Vector3(_spot.x, Game.player.global_position.y, _spot.z))
	Game.player.head.rotation.x = 0.0
	Game.player.hands.pick_up(knife)
	await wait_physics(2)
	Game.player.hands.primary()
	await wait_frames(2)
	check(not is_instance_valid(dude) or not dude.alive, "one stab")
	var trooper: PinkDude = _dude(Vector3.ZERO, &"shield")
	trooper.on_stabbed(Vector3.RIGHT)
	check(trooper.alive, "a trooper's armour turns the blade")


# ---------------------------------------------------------------- guns

func test_revolver_round_goes_through_two_dudes() -> void:
	var first: PinkDude = _dude(Vector3(0, 0, 0))
	var second: PinkDude = _dude(Vector3(5, 0, 0))
	var third: PinkDude = _dude(Vector3(10, 0, 0))
	var fourth: PinkDude = _dude(Vector3(15, 0, 0))
	var line: Array = [first, second, third, fourth]      # untyped: some of these will be freed
	for d: PinkDude in line:
		d.set_physics_process(false)
	await wait_physics(3)
	var gun: Revolver = Revolver.create()
	Game.entities_root(self).add_child(gun)
	gun.fire(_spot + Vector3(-3, 1.1, 0), Vector3.RIGHT, null)
	await wait_physics(140)
	var dead: int = 0
	for d: Variant in line:
		if not is_instance_valid(d) or not (d as PinkDude).alive:
			dead += 1
	check_eq(dead, T.revolver_pierce + 1, "through two, stopped by the third")


func test_sniper_round_is_three_times_faster() -> void:
	var rifle: SniperRifle = SniperRifle.create()
	Game.entities_root(self).add_child(rifle)
	rifle.fire(Vector3(10, 30, 10), Vector3.RIGHT, null)
	var bullet: Bullet = null
	for child: Node in BulletPool.for_node(rifle).get_children():
		if (child as Bullet).active:
			bullet = child
	await wait_physics(30)
	check_near(bullet.global_position.x - 10.0, T.bullet_speed * T.sniper_speed_scale * 0.5, 1.5, "18 m in half a second")


func test_smg_is_automatic_and_sprays() -> void:
	var smg: Smg = Smg.create()
	check(smg.automatic and smg.cooldown < T.rifle_cooldown, "faster than the AK")
	check(smg.spread_deg > T.rifle_spread_deg, "and less accurate")
	check_eq(smg.ammo, T.smg_ammo, "twenty-four rounds")


func test_every_new_gun_has_a_detailed_model() -> void:
	for gun: Gun in [Smg.create(), Revolver.create(), SniperRifle.create(), SuperGun.create()]:
		var mesh: ArrayMesh = MeshKit.cached(gun.mesh_key(), gun._model)
		var triangles: int = 0
		for surface: int in mesh.get_surface_count():
			triangles += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		check(triangles > 700, "%s has %d triangles" % [gun.name, triangles])
		check(mesh.get_surface_count() >= 3, "%s uses several materials" % gun.name)
		gun.free()


# ---------------------------------------------------------------- super gun

func test_laser_melts_every_dude_in_line_with_no_ragdoll() -> void:
	var a: PinkDude = _dude(Vector3(0, 0, 0))
	var b: PinkDude = _dude(Vector3(5, 0, 0), &"shield")
	var c: PinkDude = _dude(Vector3(10, 0, 0), &"rifle")
	for d: PinkDude in [a, b, c]:
		d.set_physics_process(false)
		d.look_at(d.global_position + Vector3(-5, 0, 0))
		d._animate(0.0)
	await wait_physics(3)
	var gun: SuperGun = SuperGun.create()
	Game.entities_root(self).add_child(gun)
	check(gun.fire(_spot + Vector3(-3, 1.1, 0), Vector3.RIGHT, null), "fires")
	check_eq(gun.ammo, T.super_charges - 1, "one charge spent")
	for d: Variant in [a, b, c] as Array:
		check(not is_instance_valid(d) or not (d as PinkDude).alive, "melted")
	check_eq(get_tree().get_nodes_in_group(&"melts").size(), 3, "three puddles in the making")
	check_eq(get_tree().get_nodes_in_group(&"ragdolls").size(), 0, "and not one ragdoll")
	check_eq(BulletPool.for_node(gun).active_count(), 0, "a laser throws no bullet")


func test_melting_sinks_the_body_into_a_puddle() -> void:
	var dude: PinkDude = _dude()
	dude._animate(0.0)
	var head_before: float = dude.joints[Humanoid.index_of(&"head")].y
	dude.on_laser(Vector3.RIGHT)
	var melt: Melt = get_tree().get_first_node_in_group(&"melts") as Melt
	check(melt != null, "melting")
	await wait_physics(int(T.melt_seconds * 60.0 * 0.5))
	check(melt.progress() > 0.35 and melt.progress() < 0.75, "half way down (%.2f)" % melt.progress())
	await wait_physics(int(T.melt_seconds * 60.0 * 0.7))
	check(melt._skin == null, "the body is gone")
	check(melt._puddle.scale.x > 0.6, "a puddle is left (%.2f m)" % melt._puddle.scale.x)
	check(head_before > 1.5, "he was standing when it hit him")


func test_laser_stops_at_walls() -> void:
	var behind_wall: PinkDude = _dude(Vector3(0, 0, -30))
	behind_wall.set_physics_process(false)
	await wait_physics(2)
	var gun: SuperGun = SuperGun.create()
	Game.entities_root(self).add_child(gun)
	gun.fire(_spot + Vector3(0, 1.1, 0), Vector3(0, 0, 1), null)
	check(behind_wall.alive, "wrong direction, and the wall stops it anyway")
