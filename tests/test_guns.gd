extends "res://tests/test_case.gd"

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	await wait_frames(1)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Input.action_release(&"primary")
	Game.unload_level()


func _surface_triangles(mesh: Mesh) -> int:
	var total: int = 0
	for s: int in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total


func test_models_are_detailed_and_cheap_to_draw() -> void:
	var ak: ArrayMesh = MeshKit.cached(&"ak47", Rifle.create()._model)
	var shotgun: ArrayMesh = MeshKit.cached(&"shotgun", Shotgun.create()._model)
	var pistol: ArrayMesh = MeshKit.cached(&"pistol", Pistol.create()._model)
	# A box is 12 triangles, so these floors mean well over a hundred parts for the AK.
	check(_surface_triangles(ak) > 2200, "AK-47 has %d triangles" % _surface_triangles(ak))
	check(_surface_triangles(shotgun) > 1500, "shotgun has %d triangles" % _surface_triangles(shotgun))
	check(_surface_triangles(pistol) > 500, "pistol has %d triangles" % _surface_triangles(pistol))
	check(ak.get_surface_count() <= 7, "AK merged into %d surfaces, one per material" % ak.get_surface_count())
	check(ak.get_surface_count() >= 5, "AK uses wood, bakelite and several metals")
	var size: Vector3 = ak.get_aabb().size
	check(size.z > 0.80 and size.z < 0.95, "AK is about 87 cm long (%.2f)" % size.z)
	check(shotgun.get_aabb().size.z > 0.95, "shotgun is about a metre long")


func test_mesh_kit_shares_one_mesh_between_guns() -> void:
	var a: Rifle = Rifle.create()
	var b: Rifle = Rifle.create()
	world.add_child(a)
	world.add_child(b)
	var mesh_a: Mesh = (a.get_child(1).get_child(0) as MeshInstance3D).mesh
	var mesh_b: Mesh = (b.get_child(1).get_child(0) as MeshInstance3D).mesh
	check(mesh_a == mesh_b, "both rifles draw the same cached mesh")


func test_rifle_is_automatic_and_holds_thirty() -> void:
	var ak: Rifle = Rifle.create()
	check_eq(ak.ammo, 30, "thirty rounds")
	check(ak.automatic, "automatic")
	check(ak.two_handed, "needs both hands")
	check(ak.cooldown < 0.15, "fast cycle")


func test_holding_the_trigger_empties_a_rifle_but_fires_a_pistol_once() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var ak: Rifle = Rifle.create()
	Game.entities_root(self).add_child(ak)
	Game.player.hands.pick_up(ak)
	Input.action_press(&"primary")
	await wait_physics(60)
	Input.action_release(&"primary")
	var fired: int = T.rifle_ammo - ak.ammo
	check(fired >= 7 and fired <= 11, "one second of automatic fire is about ten rounds (%d)" % fired)

	Game.player.hands.throw_held()
	var pistol: Pistol = Pistol.create()
	Game.entities_root(self).add_child(pistol)
	Game.player.hands.pick_up(pistol)
	Input.action_press(&"primary")
	await wait_physics(60)
	Input.action_release(&"primary")
	check_eq(pistol.ammo, T.pistol_ammo - 1, "a pistol fires once per pull however long you hold it")


func test_shotgun_throws_a_cone_of_pellets() -> void:
	var gun: Shotgun = Shotgun.create()
	world.add_child(gun)
	await wait_physics(1)
	check(gun.fire(Vector3(0, 50, 0), Vector3.FORWARD, null), "fires")
	check_eq(gun.ammo, T.shotgun_ammo - 1, "one shell spent")
	var pool: BulletPool = BulletPool.for_node(gun)
	check_eq(pool.active_count(), T.shotgun_pellets, "eight pellets in the air from one shell")
	var cone: float = deg_to_rad(T.shotgun_spread_deg) + 0.001
	var distinct: Dictionary[Vector3, bool] = {}
	for child: Node in pool.get_children():
		var b: Bullet = child as Bullet
		if b.active:
			distinct[b.direction.snappedf(0.001)] = true
			check(b.direction.angle_to(Vector3.FORWARD) <= cone, "pellet inside the cone")
	check(distinct.size() >= T.shotgun_pellets - 1, "pellets spread out, not stacked")
	check(not gun.can_fire(), "has to be racked before the next shot")


func test_scatter_stays_in_its_cone() -> void:
	var cone: float = deg_to_rad(5.0)
	for i: int in 200:
		var d: Vector3 = Gun.scatter(Vector3(0.3, 0.1, -1).normalized(), cone)
		check(d.angle_to(Vector3(0.3, 0.1, -1).normalized()) <= cone + 0.0005, "inside the cone")
		check_near(d.length(), 1.0, 0.0001, "unit length")
	check_eq(Gun.scatter(Vector3.FORWARD, 0.0), Vector3.FORWARD, "no spread means no change")


func test_dudes_get_gentler_shotguns_and_the_player_gets_the_real_one() -> void:
	var dude: PinkDude = preload("res://enemies/pink_dude.tscn").instantiate()
	dude.weapon_kind = &"shotgun"
	world.add_child(dude)
	dude.sense_override = true
	dude.set_physics_process(false)
	var gun: Gun = dude.weapon
	check(gun is Shotgun, "armed with a shotgun")
	check_eq(gun.pellets, T.shotgun_enemy_pellets, "fewer pellets in a dude's hands")
	check_near(dude.engage_distance(), T.shotgun_enemy_range, 0.01, "and he has to get close")
	dude.disarm()
	check_eq(gun.pellets, T.shotgun_pellets, "full pellets once it leaves his hands")
	check(gun.ammo <= T.shotgun_drop_ammo, "dropped with a few shells")


func test_rifle_dude_fires_a_burst() -> void:
	var dude: PinkDude = preload("res://enemies/pink_dude.tscn").instantiate()
	dude.weapon_kind = &"rifle"
	world.add_child(dude)
	dude.sense_override = true
	dude.set_physics_process(false)
	dude.can_see_player = true
	dude.dist_to_player = 8.0
	dude.change_state(&"fire")
	for i: int in 40:
		dude.tick(1.0 / 60.0)
		dude.weapon.cooldown_left = 0.0
	check_eq(BulletPool.for_node(dude).active_count(), T.rifle_enemy_burst, "three-round burst")
	check_eq(dude.state_name, &"reposition", "then he moves")


func test_bullet_is_a_black_round_with_a_pink_trail() -> void:
	var bullet: Bullet = BulletPool.for_node(world).fire(Vector3.ZERO, Vector3.FORWARD, null)
	var round_mesh: Mesh = (bullet.get_child(0).get_child(0) as MeshInstance3D).mesh
	var body: StandardMaterial3D = round_mesh.surface_get_material(0)
	check(body.albedo_color.v < 0.1, "the round is black")
	check(not body.emission_enabled, "and does not glow")
	var trail: StandardMaterial3D = ((bullet.get_child(1) as MeshInstance3D).mesh as CylinderMesh).material
	check(trail.albedo_color.r > 0.9 and trail.albedo_color.g < 0.4, "the trail is pink")
	check(trail.emission_enabled, "and glows")
	var aabb: AABB = round_mesh.get_aabb()
	check(aabb.size.z > aabb.size.x * 2.5, "longer than wide, like a bullet (%.3f by %.3f)" % [aabb.size.z, aabb.size.x])
	check(aabb.position.z < -0.07, "with a pointed nose leading")
	await wait_physics(30)
	check((bullet.get_child(1) as Node3D).scale.y > 0.5, "trail stretches out behind it as it flies")


func test_pellets_are_smaller_than_bullets() -> void:
	var pool: BulletPool = BulletPool.for_node(world)
	var big: Bullet = pool.fire(Vector3.ZERO, Vector3.FORWARD, null, 1.0)
	var small: Bullet = pool.fire(Vector3.ZERO, Vector3.FORWARD, null, 0.6)
	check((small.get_child(0) as Node3D).scale.x < (big.get_child(0) as Node3D).scale.x, "pellet drawn smaller")


func test_floors_have_the_new_guns() -> void:
	var rifles: int = 0
	var shotguns: int = 0
	var rifle_dudes: int = 0
	var shotgun_dudes: int = 0
	for floor_name: String in Game.FLOORS:
		var d: LevelData = LevelParser.load_level(floor_name)
		for p: Dictionary in d.pickups:
			rifles += 1 if p["kind"] == &"rifle" else 0
			shotguns += 1 if p["kind"] == &"shotgun" else 0
		for sp: Dictionary in d.spawns:
			rifle_dudes += 1 if sp["weapon"] == &"rifle" else 0
			shotgun_dudes += 1 if sp["weapon"] == &"shotgun" else 0
	check(rifles >= 3, "AKs to find (%d)" % rifles)
	check(shotguns >= 3, "shotguns to find (%d)" % shotguns)
	check(rifle_dudes >= 4, "riflemen (%d)" % rifle_dudes)
	check(shotgun_dudes >= 2, "shotgunners (%d)" % shotgun_dudes)
