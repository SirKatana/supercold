class_name SuperGun
extends Gun
## The prize for beating the Brute. It fires a laser: instant, through every dude in the
## line, and whoever it touches melts where he stands. Eight charges, refilled every level.


static func create(rounds: int = -1) -> SuperGun:
	var g := SuperGun.new()
	g.kind = &"super"
	g.name = "SuperGun"
	g.capacity = T.super_charges
	g.ammo = T.super_charges if rounds < 0 else rounds
	g.cooldown = T.super_cooldown
	g.two_handed = true
	g.muzzle_local = Vector3(0, 0.046, -0.50)
	g.hold_offset = Vector3(-0.015, 0.0, 0.02)
	g.burst_strength = 0.28
	g.kick = 0.05
	g.drop_ammo = 0
	g.sound = &"laser"
	g.blunt_damage = 2
	return g


## It is yours. You won it. Security has been told.
func is_weapon() -> bool:
	return false


func mesh_key() -> StringName:
	return &"super_gun"


func _model(kit: MeshKit) -> void:
	var shell: Material = Mats.white_paint()
	var dark: Material = Mats.polymer()
	var steel: Material = Mats.steel()
	var copper: Material = Mats.copper()
	var hot: Material = Mats.laser()
	var cold: Material = Mats.accent()
	kit.box(Vector3(0.060, 0.080, 0.300), Vector3(0, 0.034, -0.060), shell)               # body
	kit.box(Vector3(0.064, 0.020, 0.200), Vector3(0, 0.080, -0.050), dark)                # top spine
	for i: int in 9:                                                                      # heat sink fins
		kit.box(Vector3(0.082, 0.070, 0.006), Vector3(0, 0.040, -0.150 + i * 0.022), steel)
	kit.tube(0.0200, 0.0200, 0.260, Vector3(0, 0.046, -0.340), dark, true, 14)            # emitter housing
	for i: int in 5:                                                                      # copper focusing coils
		kit.tube(0.0245, 0.0245, 0.016, Vector3(0, 0.046, -0.250 - i * 0.042), copper, true, 14)
	kit.tube(0.0115, 0.0115, 0.270, Vector3(0, 0.046, -0.345), hot, true, 12)             # the glowing core
	kit.tube(0.0300, 0.0230, 0.040, Vector3(0, 0.046, -0.485), steel, true, 14)           # emitter bell
	for i: int in 3:                                                                      # three prongs round the lens
		var a: float = i * TAU / 3.0 + PI * 0.5
		kit.box(Vector3(0.008, 0.008, 0.060), Vector3(cos(a) * 0.030, 0.046 + sin(a) * 0.030, -0.505), steel)
	kit.tube(0.0160, 0.0160, 0.004, Vector3(0, 0.046, -0.506), hot, true, 12)             # lens
	# Battery pack with charge lamps, and the cable that feeds the emitter.
	kit.box(Vector3(0.052, 0.070, 0.110), Vector3(0, -0.040, -0.110), dark)
	for i: int in 4:
		kit.box(Vector3(0.006, 0.010, 0.014), Vector3(0.0275, -0.020, -0.145 + i * 0.024), cold)
		kit.box(Vector3(0.006, 0.010, 0.014), Vector3(-0.0275, -0.020, -0.145 + i * 0.024), cold)
	kit.box(Vector3(0.056, 0.008, 0.116), Vector3(0, -0.079, -0.110), steel)
	for i: int in 6:
		kit.ball(0.0075, Vector3(0.036, 0.010 + sin(i * 0.9) * 0.012, -0.200 - i * 0.030), dark)   # cable
	kit.box(Vector3(0.0605, 0.004, 0.280), Vector3(0, 0.006, -0.060), cold)               # cold accent line
	kit.box(Vector3(0.020, 0.030, 0.050), Vector3(0, 0.104, -0.020), dark)                # sight block
	kit.box(Vector3(0.014, 0.014, 0.004), Vector3(0, 0.108, -0.046), hot)                 # holo dot
	kit.box(Vector3(0.012, 0.004, 0.070), Vector3(0, -0.036, 0.020), dark)
	kit.box(Vector3(0.012, 0.034, 0.004), Vector3(0, -0.020, -0.014), dark)
	kit.box(Vector3(0.005, 0.022, 0.006), Vector3(0, -0.016, 0.024), copper, Vector3(0.35, 0, 0))
	kit.base = Transform3D(Basis(Vector3.RIGHT, -0.26), Vector3(0, -0.004, 0.075))
	kit.box(Vector3(0.034, 0.105, 0.048), Vector3(0, -0.052, 0), dark)
	for i: int in 5:
		kit.box(Vector3(0.036, 0.004, 0.042), Vector3(0, -0.024 - i * 0.016, 0), Mats.rubber())
	kit.base = Transform3D.IDENTITY
	kit.box(Vector3(0.050, 0.070, 0.150), Vector3(0, 0.030, 0.160), shell)                # stub stock
	kit.box(Vector3(0.052, 0.080, 0.016), Vector3(0, 0.030, 0.240), Mats.rubber())


## A laser does not throw a bullet. It draws a line and melts what is on it.
func fire(origin: Vector3, direction: Vector3, shooter: Node, spend: bool = true) -> bool:
	if not can_fire():
		return false
	if spend:
		ammo -= 1
		ammo_changed.emit(ammo)
	cooldown_left = cooldown
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var skip: Array[RID] = []
	if shooter is CollisionObject3D:
		skip.append((shooter as CollisionObject3D).get_rid())
		if shooter.has_method(&"bullet_excludes"):
			skip.append_array(shooter.call(&"bullet_excludes"))
	var end: Vector3 = origin + direction * T.super_range
	var from: Vector3 = origin
	for step: int in 24:
		var query := PhysicsRayQueryParameters3D.create(from, end, 1 | 4 | 32 | 128)
		query.collide_with_areas = true
		query.exclude = skip
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit["collider"]
		skip.append(hit["rid"])
		# Duck typing on purpose. PinkDude creates this gun, so naming PinkDude (or anything
		# that names it) here makes a dependency loop GDScript cannot resolve.
		if collider.has_method(&"on_laser"):
			collider.call(&"on_laser", direction)      # a dude: melt him and carry straight on
			continue
		if collider.has_method(&"laser_passes"):
			continue                                   # a shield plate does not stop it
		if collider.has_method(&"on_bullet_hit"):
			# Glass goes. Barrels, freeze bombs and fart clouds go off. Doors burn through.
			if collider is Node and (collider as Node).is_in_group(&"doors"):
				collider.call(&"take_damage", 99, direction, hit["position"])
			else:
				collider.call(&"on_bullet_hit", null, hit["position"], hit["normal"])
			continue
		end = hit["position"]                          # a wall: the beam stops here
		Shatter.burst(Game.entities_root(self), end + (hit["normal"] as Vector3) * 0.05, 8, Mats.laser(), Vector3.ONE * 0.04,
			(hit["normal"] as Vector3) * 2.0, 0.05)
		break
	LaserBeam.draw(Game.entities_root(self), origin, end)
	Sfx.play(sound, origin)
	if spend:
		Game.emit_noise(origin, T.gunshot_hearing)
	return true
