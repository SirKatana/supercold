extends "res://tests/test_case.gd"



func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true


func after_each() -> void:
	Shield.deflect_chance_override = -1.0
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


## An empty room with one shield trooper, facing the player, senses frozen so he stands still.
func _room_with_trooper() -> ShieldDude:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	for node: Node in get_tree().get_nodes_in_group(&"barrels"):
		node.free()
	Game.alive_enemies = 0
	var spot: Vector3 = Game.data.cell_center(Vector2i(10, 8), 0.05)
	var trooper: ShieldDude = Game.spawn_dude(spot, true, &"shield") as ShieldDude
	trooper.sense_override = true
	trooper.set_physics_process(false)
	trooper.look_at(spot + Vector3(-5, 0, 0))
	trooper._animate(0.0)
	await wait_physics(3)
	return trooper


func _fire(from: Vector3, at: Vector3) -> Bullet:
	return BulletPool.for_node(Game.player).fire(from, (at - from).normalized(), null)


func _wait_for(bullet: Bullet, ticks: int = 60) -> void:
	for i: int in ticks:
		if not bullet.active:
			return
		await wait_physics(1)


func test_trooper_carries_a_shield_with_intact_glass() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	check(trooper.shield != null, "has a shield")
	check(trooper.shield.glass_intact, "glass intact")
	check(trooper.has_weapon(), "and a pistol")
	check(not trooper.seeks_cover(), "he does not hide")
	check(trooper.move_speed() < T.dude_speed, "and he is slow")


func test_bullets_on_the_plate_never_kill_him() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	Shield.deflect_chance_override = 0.0
	var front: Vector3 = trooper.global_position + Vector3(-4, 0, 0)
	for i: int in 6:
		var bullet: Bullet = _fire(front + Vector3(0, 1.1, 0), trooper.global_position + Vector3(0, 1.0 + i * 0.05, 0))
		await _wait_for(bullet)
		check(not bullet.active, "round %d stopped on the shield (bullet at %s, trooper at %s, shield at %s)" % [
			i, bullet.global_position, trooper.global_position, trooper.shield.global_position])
	check(trooper.alive, "six rounds into the plate and he is fine")


func test_a_bullet_through_the_glass_kills_him_and_he_drops_the_shield() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	var shield: Shield = trooper.shield
	var glass: Vector3 = shield.global_transform * Vector3(0, Shield.VISOR_Y, -0.06)
	var bullet: Bullet = _fire(glass + Vector3(-4, 0, 0), glass)
	await _wait_for(bullet)
	await wait_frames(2)
	check(not is_instance_valid(trooper) or not trooper.alive, "dead")
	check(not shield.glass_intact, "glass broke")
	check_eq(shield.state, Pickup.State.RESTING, "shield is on the floor")
	check(shield.holder_dude == null, "and belongs to nobody")


func test_his_armour_stops_bullets_from_behind_too() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	Shield.deflect_chance_override = 0.0
	var behind: Vector3 = trooper.global_position + Vector3(4, 1.1, 0)
	var bullet: Bullet = _fire(behind, trooper.global_position + Vector3(0, 1.1, 0))
	await _wait_for(bullet)
	check(trooper.alive, "the glass is the only way in")


func test_blunt_hits_and_the_ram_only_stagger_him() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	for i: int in 5:
		trooper.on_punched(self, Vector3.ZERO)
	trooper.on_rammed(Vector3.LEFT)
	check(trooper.alive, "still standing")
	check(trooper.has_weapon(), "still armed")
	check_eq(trooper.state_name, &"stunned", "but staggered")


func test_deflect_chance_is_about_one_in_three() -> void:
	check_near(T.shield_deflect_chance, 1.0 / 3.0, 0.001, "tuned to a third")
	var trooper: ShieldDude = await _room_with_trooper()
	var front: Vector3 = trooper.global_position + Vector3(-3, 1.0, 0)
	var bounced: int = 0
	var shots: int = 90
	for i: int in shots:
		var bullet: Bullet = _fire(front, trooper.global_position + Vector3(0, 1.0, 0))
		var state: Dictionary = {"bounced": false}
		var on_deflect: Callable = func(_by: Object) -> void: state["bounced"] = true
		bullet.deflected.connect(on_deflect)
		for t: int in 30:
			await wait_physics(1)
			if state["bounced"] or not bullet.active:
				break
		bullet.deflected.disconnect(on_deflect)
		if state["bounced"]:
			bounced += 1
		bullet.deactivate()
	check(bounced >= 16 and bounced <= 46, "%d of %d ricocheted, expected about %d" % [bounced, shots, shots / 3])


func test_a_ricochet_flies_away_and_belongs_to_nobody() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	Shield.deflect_chance_override = 1.0
	var front: Vector3 = trooper.global_position + Vector3(-3, 1.0, 0)
	var bullet: Bullet = BulletPool.for_node(Game.player).fire(front, Vector3.RIGHT, Game.player)
	var state: Dictionary = {"bounced": false}
	bullet.deflected.connect(func(_by: Object) -> void: state["bounced"] = true, CONNECT_ONE_SHOT)
	for t: int in 40:
		await wait_physics(1)
		if state["bounced"]:
			break
	check(state["bounced"], "it bounced")
	check(bullet.active, "and keeps flying")
	check(bullet.direction.x < 0.0, "back the way it came (%.2f)" % bullet.direction.x)
	check(bullet.shooter == null, "so it can now hit whoever fired it")
	bullet.deactivate()


func test_player_takes_the_shield_with_f_wears_it_and_it_stops_bullets() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	var shield: Shield = trooper.shield
	trooper.visor_shot(Vector3.RIGHT)
	await wait_frames(2)
	Game.god_mode = false
	Shield.deflect_chance_override = 0.0
	var player: Player = Game.player
	player.global_position = shield.grab_point() * Vector3(1, 0, 1) + Vector3(-1.0, 0.05, 0)
	player.look_at(player.global_position + Vector3(8, 0, 0))
	player.head.rotation.x = 0.0
	await wait_physics(2)
	check(player.hands.nearest_shield() == shield, "the shield is in reach")
	check(player.hands.toggle_shield(), "F takes it")
	check(player.shield == shield and shield.worn, "and it is worn")
	check(player.hands.held == null, "the gun hand stays free")
	await wait_physics(2)

	# Straight at the chest from the front: the plate takes it.
	var bullet: Bullet = _fire(player.chest_position() + Vector3(5, 0, 0), player.chest_position())
	await _wait_for(bullet)
	check(player.alive, "shield stopped a bullet from the front")
	# From behind there is no shield.
	var second: Bullet = _fire(player.chest_position() + Vector3(-5, 0, 0), player.chest_position())
	await _wait_for(second)
	check(not player.alive, "a bullet in the back still kills")
	check_eq(shield.state, Pickup.State.RESTING, "and the shield falls with him")


func test_players_own_shots_do_not_hit_the_shield_they_wear() -> void:
	var trooper: ShieldDude = await _room_with_trooper()
	var shield: Shield = trooper.shield
	trooper.visor_shot(Vector3.RIGHT)
	await wait_frames(2)
	var player: Player = Game.player
	player.global_position = shield.grab_point() * Vector3(1, 0, 1) + Vector3(-1.0, 0.05, 0)
	player.look_at(player.global_position + Vector3(-8, 0, 0))
	player.head.rotation.x = 0.0
	await wait_physics(2)
	player.hands.toggle_shield()
	var pistol: Pistol = Pistol.create()
	Game.entities_root(self).add_child(pistol)
	player.hands.pick_up(pistol)
	await wait_physics(2)
	player.hands.primary()
	var bullet: Bullet = null
	for child: Node in BulletPool.for_node(player).get_children():
		if (child as Bullet).active:
			bullet = child
	check(bullet != null, "fired")
	await wait_physics(12)
	check(bullet.active and bullet.global_position.distance_to(player.global_position) > 1.5, "the round left past the shield")
	check(player.hands.toggle_shield(), "F again drops it")
	check(player.shield == null and shield.state == Pickup.State.RESTING, "back on the floor")


func test_barrel_explodes_when_shot_and_kills_everyone_in_the_radius() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	for node: Node in get_tree().get_nodes_in_group(&"barrels"):
		node.free()
	Game.alive_enemies = 0
	var centre: Vector3 = Game.data.cell_center(Vector2i(10, 8), 0.0)
	var barrel: GasBarrel = GasBarrel.create()
	Game.entities_root(self).add_child(barrel)
	barrel.global_position = centre
	var near: PinkDude = Game.spawn_dude(centre + Vector3(2.5, 0.05, 0), true)
	var trooper: PinkDude = Game.spawn_dude(centre + Vector3(-2.5, 0.05, -2.5), true, &"shield")
	var far: PinkDude = Game.spawn_dude(centre + Vector3(0, 0.05, -11), true)
	for d: PinkDude in [near, trooper, far]:
		d.sense_override = true
	Game.player.global_position = centre + Vector3(-14, 0.05, 0)
	await wait_physics(3)
	var bullet: Bullet = _fire(centre + Vector3(-5, 0.5, 0), centre + Vector3(0, 0.45, 0))
	await _wait_for(bullet)
	await wait_frames(2)
	check(not is_instance_valid(barrel), "the barrel is gone")
	check(not is_instance_valid(near) or not near.alive, "dude in the radius died")
	check(not is_instance_valid(trooper) or not trooper.alive, "a blast kills a shield trooper too")
	check(is_instance_valid(far) and far.alive, "dude outside the radius lived")
	check(get_tree().get_nodes_in_group(&"ragdolls").size() >= 2, "the dead were thrown as ragdolls")


func test_thrown_barrel_explodes_on_impact() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var barrel: GasBarrel = GasBarrel.create()
	Game.entities_root(self).add_child(barrel)
	var from: Vector3 = Game.data.cell_center(Vector2i(4, 8), 1.4)
	Game.player.global_position = from + Vector3(-6, -1.35, 0)
	barrel.throw_from(from, Vector3(9, 1, 0), null)
	await wait_physics(120)
	check(not is_instance_valid(barrel), "it went off when it landed")


func test_barrels_chain_and_walls_block_the_blast() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0
	var a: GasBarrel = GasBarrel.create()
	var b: GasBarrel = GasBarrel.create()
	Game.entities_root(self).add_child(a)
	Game.entities_root(self).add_child(b)
	a.global_position = Game.data.cell_center(Vector2i(7, 5), 0.0)
	b.global_position = Game.data.cell_center(Vector2i(8, 6), 0.0)
	# This dude is 3 m from barrel a, but on the far side of a solid wall.
	var shielded: PinkDude = Game.spawn_dude(Game.data.cell_center(Vector2i(4, 5), 0.05), true)
	shielded.sense_override = true
	Game.player.global_position = Game.data.cell_center(Vector2i(1, 1), 0.05)
	await wait_physics(3)
	a.explode()
	check(not b.exploded, "the second barrel does not go at the same instant")
	await wait_physics(60)
	check(not is_instance_valid(b), "but it cooks off a moment later")
	check(is_instance_valid(shielded) and shielded.alive, "a wall between you and the blast saves you")


func test_blast_kills_a_player_standing_next_to_it() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	Game.god_mode = false
	var barrel: GasBarrel = GasBarrel.create()
	Game.entities_root(self).add_child(barrel)
	barrel.global_position = Game.player.global_position + Vector3(2.0, 0, 3.0)
	Game.player.global_position += Vector3(2.0, 0, 1.0)
	await wait_physics(2)
	barrel.explode()
	check(not Game.player.alive, "do not stand next to it")


func test_barrel_stands_solid_and_has_a_warning_sign() -> void:
	var barrel: GasBarrel = GasBarrel.create()
	add_child(barrel)
	await wait_physics(2)
	var space: PhysicsDirectSpaceState3D = barrel.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-2, 0.4, 0), Vector3(2, 0.4, 0), 1)
	check(not space.intersect_ray(ray).is_empty(), "you cannot walk through it")
	var mesh: ArrayMesh = MeshKit.cached(&"gas_barrel", GasBarrel._model)
	var colours: Array[Color] = []
	for s: int in mesh.get_surface_count():
		colours.append((mesh.surface_get_material(s) as StandardMaterial3D).albedo_color)
	check(colours.has(Mats.barrel_red().albedo_color), "it is red")
	check(colours.has(Mats.hazard_yellow().albedo_color), "with a yellow hazard diamond")
	barrel.free()


func test_floors_have_troopers_and_barrels() -> void:
	var troopers: int = 0
	var barrels: int = 0
	for floor_name: String in Game.FLOORS:
		var d: LevelData = LevelParser.load_level(floor_name)
		for sp: Dictionary in d.spawns:
			troopers += 1 if sp["weapon"] == &"shield" else 0
		for p: Dictionary in d.pickups:
			barrels += 1 if p["kind"] == &"barrel" else 0
	check(troopers >= 4, "shield troopers placed (%d)" % troopers)
	check(barrels >= 12, "gas barrels placed (%d)" % barrels)
