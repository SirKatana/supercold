class_name SniperRifle
extends Gun
## Bolt-action rifle with a scope. Four rounds, three times the speed, straight through four dudes.


static func create(rounds: int = -1) -> SniperRifle:
	var g := SniperRifle.new()
	g.kind = &"sniper"
	g.name = "SniperRifle"
	g.capacity = T.sniper_ammo
	g.ammo = T.sniper_ammo if rounds < 0 else rounds
	g.cooldown = T.sniper_cooldown
	g.pierce = T.sniper_pierce
	g.bullet_speed_scale = T.sniper_speed_scale
	g.bullet_scale = 1.15
	g.two_handed = true
	g.has_scope = true
	g.muzzle_local = Vector3(0, 0.040, -0.82)
	g.hold_offset = Vector3(-0.015, 0.0, 0.06)
	g.burst_strength = 0.30
	g.kick = 0.12
	g.drop_ammo = 2
	g.enemy_range = 60.0
	g.enemy_aim_time = T.sniper_enemy_aim_time
	g.blunt_damage = 2
	return g


func mesh_key() -> StringName:
	return &"sniper"


func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.parkerized()
	var bright: Material = Mats.steel()
	var poly: Material = Mats.polymer()
	var wood: Material = Mats.wood_dark()
	var grain: Material = Mats.polymer()
	kit.tube(0.0095, 0.0120, 0.560, Vector3(0, 0.040, -0.520), steel, true, 14)           # heavy barrel
	for i: int in 6:
		kit.tube(0.0108, 0.0112, 0.030, Vector3(0, 0.040, -0.430 - i * 0.055), bright, true, 14)   # fluting bands
	kit.tube(0.0170, 0.0170, 0.075, Vector3(0, 0.040, -0.800), steel, true, 12)           # muzzle brake
	for i: int in 3:
		kit.box(Vector3(0.036, 0.008, 0.010), Vector3(0, 0.040, -0.780 - i * 0.020), poly)  # brake ports
	kit.tube(0.0060, 0.0060, 0.005, Vector3(0, 0.040, -0.840), poly, true, 10)
	kit.tube(0.0175, 0.0175, 0.230, Vector3(0, 0.040, -0.120), steel, true, 14)           # receiver
	kit.box(Vector3(0.003, 0.014, 0.070), Vector3(0.0170, 0.044, -0.130), poly)           # ejection port
	kit.tube(0.0050, 0.0050, 0.050, Vector3(0.040, 0.036, -0.030), bright, false, 8, Vector3(0, 0, PI * 0.5))   # bolt handle
	kit.ball(0.0105, Vector3(0.066, 0.032, -0.030), bright)                               # bolt knob
	kit.tube(0.0100, 0.0100, 0.030, Vector3(0, 0.040, 0.010), bright, true, 10)           # bolt shroud
	# Scope: tube, bells, turrets, two rings.
	kit.tube(0.0150, 0.0150, 0.220, Vector3(0, 0.092, -0.130), poly, true, 14)
	kit.tube(0.0230, 0.0170, 0.070, Vector3(0, 0.092, -0.270), poly, true, 14)            # objective bell
	kit.tube(0.0190, 0.0200, 0.050, Vector3(0, 0.092, 0.000), poly, true, 14)             # eyepiece
	kit.tube(0.0215, 0.0215, 0.004, Vector3(0, 0.092, -0.306), Mats.visor_glass(), true, 14)   # lens
	kit.tube(0.0100, 0.0100, 0.024, Vector3(0, 0.116, -0.130), bright, false, 10)         # elevation turret
	kit.tube(0.0100, 0.0100, 0.024, Vector3(0.024, 0.092, -0.130), bright, false, 10, Vector3(0, 0, PI * 0.5))   # windage turret
	for z: float in [-0.190, -0.070]:
		kit.box(Vector3(0.022, 0.044, 0.016), Vector3(0, 0.070, z), steel)                # ring and base
	kit.box(Vector3(0.020, 0.008, 0.170), Vector3(0, 0.054, -0.130), steel)               # scope rail
	# Stock: fore-end, magazine, guard, thumbhole grip, cheek piece, butt pad, bipod.
	kit.box(Vector3(0.046, 0.042, 0.330), Vector3(0, 0.006, -0.230), wood)
	kit.box(Vector3(0.040, 0.010, 0.300), Vector3(0, -0.018, -0.230), wood)
	for side: float in [-1.0, 1.0]:
		for i: int in 5:
			kit.box(Vector3(0.0015, 0.010, 0.030), Vector3(0.0235 * side, 0.010, -0.340 + i * 0.045), grain)   # vents
		kit.tube(0.0045, 0.0045, 0.200, Vector3(0.020 * side, -0.095, -0.400), bright, false, 8, Vector3(0.0, 0, 0.30 * side))   # bipod leg
		kit.box(Vector3(0.014, 0.008, 0.018), Vector3(0.050 * side, -0.194, -0.400), Mats.rubber())                # bipod foot
	kit.box(Vector3(0.030, 0.052, 0.062), Vector3(0, -0.030, -0.090), steel)              # box magazine
	kit.box(Vector3(0.012, 0.004, 0.068), Vector3(0, -0.038, -0.010), steel)
	kit.box(Vector3(0.012, 0.032, 0.004), Vector3(0, -0.022, -0.044), steel)
	kit.box(Vector3(0.005, 0.022, 0.006), Vector3(0, -0.018, -0.006), bright, Vector3(0.35, 0, 0))
	kit.base = Transform3D(Basis(Vector3.RIGHT, 0.06), Vector3(0, 0.014, 0.060))
	kit.box(Vector3(0.040, 0.056, 0.110), Vector3(0, 0.000, 0.050), wood)                 # wrist
	kit.box(Vector3(0.036, 0.095, 0.050), Vector3(0, -0.060, 0.030), wood, Vector3(-0.30, 0, 0))   # pistol grip
	kit.box(Vector3(0.042, 0.105, 0.210), Vector3(0, -0.018, 0.210), wood)                # butt
	kit.box(Vector3(0.034, 0.030, 0.150), Vector3(0, 0.046, 0.190), poly)                 # adjustable cheek piece
	for z: float in [0.150, 0.230]:
		kit.tube(0.004, 0.004, 0.030, Vector3(0, 0.028, z), bright, false, 8)             # cheek posts
	kit.box(Vector3(0.043, 0.110, 0.022), Vector3(0, -0.018, 0.326), Mats.rubber())       # butt pad
	kit.base = Transform3D.IDENTITY
