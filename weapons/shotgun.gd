class_name Shotgun
extends Gun
## Pump-action 12 gauge. One pull throws a cone of pellets.


static func create(rounds: int = -1) -> Shotgun:
	var s := Shotgun.new()
	s.kind = &"shotgun"
	s.name = "Shotgun"
	s.capacity = T.shotgun_ammo
	s.ammo = T.shotgun_ammo if rounds < 0 else rounds
	s.cooldown = T.shotgun_cooldown
	s.pellets = T.shotgun_pellets
	s.spread_deg = T.shotgun_spread_deg
	s.bullet_scale = 0.6
	s.two_handed = true
	s.muzzle_local = Vector3(0, 0.040, -0.66)
	s.hold_offset = Vector3(-0.015, 0.048, -0.05)
	s.burst_strength = 0.30
	s.kick = 0.10
	s.blunt_damage = 2
	s.drop_ammo = T.shotgun_drop_ammo
	s.enemy_pellets = T.shotgun_enemy_pellets
	s.enemy_range = T.shotgun_enemy_range
	s._player_pellets = T.shotgun_pellets
	return s


func mesh_key() -> StringName:
	return &"shotgun"


func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.parkerized()
	var bright: Material = Mats.steel()
	var dark: Material = Mats.polymer()
	var wood: Material = Mats.wood()
	var grain: Material = Mats.wood_dark()
	var rubber: Material = Mats.rubber()
	var brass: Material = Mats.brass()
	var axis: float = 0.040

	# --- receiver: rounded top, flat sides, ejection port with a shell showing, loading port, pins
	kit.box(Vector3(0.040, 0.058, 0.215), Vector3(0, 0.022, 0.000), steel)
	kit.tube(0.020, 0.020, 0.215, Vector3(0, 0.050, 0.000), steel, true, 14)
	kit.box(Vector3(0.003, 0.022, 0.075), Vector3(0.0200, 0.040, -0.030), dark)        # ejection port
	kit.tube(0.0095, 0.0095, 0.050, Vector3(0.0165, 0.040, -0.030), brass, true, 10)   # chambered shell
	kit.box(Vector3(0.030, 0.003, 0.090), Vector3(0, -0.008, -0.030), dark)            # loading port
	kit.box(Vector3(0.022, 0.003, 0.070), Vector3(0, -0.006, -0.030), bright)          # shell lifter
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.070, 0.045]:
			kit.tube(0.0035, 0.0035, 0.003, Vector3(0.0205 * side, 0.012, z), bright, false, 8, Vector3(0, 0, PI * 0.5))
	kit.tube(0.0050, 0.0050, 0.044, Vector3(0, 0.004, 0.072), bright, false, 8, Vector3(0, 0, PI * 0.5))   # cross-bolt safety
	kit.box(Vector3(0.010, 0.006, 0.012), Vector3(0, 0.073, 0.085), bright)            # tang slide

	# --- barrel with vent rib, bead and mid bead; magazine tube with cap and clamp
	kit.tube(0.0115, 0.0125, 0.560, Vector3(0, axis, -0.385), steel, true, 14)
	kit.tube(0.0098, 0.0098, 0.004, Vector3(0, axis, -0.667), dark, true, 12)          # the bore
	kit.box(Vector3(0.008, 0.003, 0.520), Vector3(0, 0.0605, -0.395), steel)           # rib top
	for i: int in 11:
		kit.box(Vector3(0.004, 0.007, 0.006), Vector3(0, 0.0555, -0.150 - i * 0.049), steel)   # rib posts
	kit.ball(0.0032, Vector3(0, 0.0650, -0.650), brass)                                # front bead
	kit.ball(0.0020, Vector3(0, 0.0640, -0.400), bright)                               # mid bead
	kit.tube(0.0120, 0.0120, 0.440, Vector3(0, 0.012, -0.330), steel, true, 14)        # magazine tube
	kit.tube(0.0135, 0.0125, 0.030, Vector3(0, 0.012, -0.563), bright, true, 14)       # magazine cap
	for i: int in 6:
		kit.box(Vector3(0.0275, 0.003, 0.003), Vector3(0, 0.012, -0.554 - i * 0.004), dark)    # cap knurling
	kit.box(Vector3(0.012, 0.050, 0.020), Vector3(0, 0.026, -0.520), steel)            # barrel clamp
	kit.box(Vector3(0.004, 0.014, 0.018), Vector3(0, -0.006, -0.520), bright)          # front sling stud

	# --- pump fore-end: ribbed wood sleeve on the magazine tube, with its action bars
	kit.tube(0.0260, 0.0240, 0.190, Vector3(0, 0.014, -0.285), wood, true, 12)
	for i: int in 9:
		kit.tube(0.0272, 0.0272, 0.007, Vector3(0, 0.014, -0.205 - i * 0.020), grain, true, 12)
	kit.tube(0.0230, 0.0260, 0.014, Vector3(0, 0.014, -0.387), wood, true, 12)         # front lip
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.003, 0.008, 0.130), Vector3(0.0150 * side, 0.020, -0.150), bright)   # action bars

	# --- trigger group
	kit.box(Vector3(0.014, 0.004, 0.075), Vector3(0, -0.050, 0.060), steel)
	kit.box(Vector3(0.014, 0.042, 0.004), Vector3(0, -0.029, 0.024), steel)
	kit.box(Vector3(0.014, 0.030, 0.004), Vector3(0, -0.036, 0.096), steel, Vector3(-0.5, 0, 0))
	kit.box(Vector3(0.006, 0.026, 0.006), Vector3(0, -0.024, 0.062), brass, Vector3(0.35, 0, 0))
	kit.box(Vector3(0.006, 0.010, 0.012), Vector3(0, -0.012, 0.020), bright)           # action release

	# --- stock: wood, pistol-grip wrist with chequering, grain lines, white spacer, rubber recoil pad
	kit.base = Transform3D(Basis(Vector3.RIGHT, 0.11), Vector3(0, 0.022, 0.105))
	kit.box(Vector3(0.036, 0.052, 0.090), Vector3(0, -0.006, 0.040), wood)             # wrist
	kit.box(Vector3(0.034, 0.070, 0.050), Vector3(0, -0.048, 0.050), wood, Vector3(-0.45, 0, 0))   # grip drop
	kit.box(Vector3(0.0345, 0.010, 0.044), Vector3(0, -0.086, 0.070), grain, Vector3(-0.45, 0, 0)) # grip cap
	kit.box(Vector3(0.038, 0.095, 0.130), Vector3(0, -0.020, 0.150), wood)
	kit.box(Vector3(0.038, 0.122, 0.110), Vector3(0, -0.030, 0.265), wood)
	kit.box(Vector3(0.032, 0.014, 0.280), Vector3(0, 0.030, 0.180), wood)              # comb
	for side: float in [-1.0, 1.0]:
		for i: int in 6:
			kit.box(Vector3(0.0015, 0.0035, 0.250), Vector3(0.0196 * side, 0.012 - i * 0.019, 0.195), grain, Vector3(0.04, 0, 0))
		for i: int in 5:
			kit.box(Vector3(0.0015, 0.030, 0.003), Vector3(0.0186 * side, -0.040, 0.030 + i * 0.010), grain, Vector3(-0.45, 0, 0))
	kit.box(Vector3(0.039, 0.124, 0.004), Vector3(0, -0.030, 0.322), bright)           # white line spacer
	kit.box(Vector3(0.039, 0.126, 0.024), Vector3(0, -0.030, 0.336), rubber)           # recoil pad
	for i: int in 5:
		kit.box(Vector3(0.0395, 0.004, 0.018), Vector3(0, 0.020 - i * 0.025, 0.338), dark)     # pad vents
	kit.box(Vector3(0.004, 0.014, 0.018), Vector3(0, -0.098, 0.250), bright)           # rear sling stud
	kit.base = Transform3D.IDENTITY
