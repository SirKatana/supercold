class_name Smg
extends Gun
## Compact submachine gun. Twenty-four rounds, very fast, not very accurate. Hold the trigger.


static func create(rounds: int = -1) -> Smg:
	var g := Smg.new()
	g.kind = &"smg"
	g.name = "SMG"
	g.capacity = T.smg_ammo
	g.ammo = T.smg_ammo if rounds < 0 else rounds
	g.cooldown = T.smg_cooldown
	g.automatic = true
	g.spread_deg = T.smg_spread_deg
	g.bullet_scale = 0.8
	g.muzzle_local = Vector3(0, 0.040, -0.34)
	g.hold_offset = Vector3(-0.01, 0.0, 0.0)
	g.burst_strength = 0.14
	g.kick = 0.016
	g.enemy_burst = 4
	g.enemy_burst_gap = 0.09
	g.drop_ammo = 10
	g.blunt_damage = 1
	return g


func mesh_key() -> StringName:
	return &"smg"


func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.parkerized()
	var bright: Material = Mats.steel()
	var poly: Material = Mats.polymer()
	var glow: Material = Mats.accent()
	kit.box(Vector3(0.040, 0.060, 0.260), Vector3(0, 0.028, -0.060), steel)               # upper receiver
	kit.box(Vector3(0.034, 0.010, 0.220), Vector3(0, 0.063, -0.060), steel)               # top rail bed
	for i: int in 11:
		kit.box(Vector3(0.030, 0.006, 0.010), Vector3(0, 0.071, -0.160 + i * 0.020), poly)  # rail teeth
	kit.box(Vector3(0.006, 0.020, 0.012), Vector3(0, 0.084, -0.160), bright)              # front sight
	kit.box(Vector3(0.016, 0.018, 0.010), Vector3(0, 0.083, 0.040), poly)                 # rear aperture
	kit.tube(0.013, 0.013, 0.120, Vector3(0, 0.036, -0.250), steel, true, 12)             # barrel shroud
	for i: int in 5:
		kit.tube(0.0145, 0.0145, 0.008, Vector3(0, 0.036, -0.205 - i * 0.020), poly, true, 12)   # cooling rings
	kit.tube(0.0165, 0.0150, 0.040, Vector3(0, 0.036, -0.325), bright, true, 12)          # compensator
	kit.tube(0.0060, 0.0060, 0.005, Vector3(0, 0.036, -0.346), poly, true, 10)            # bore
	kit.box(Vector3(0.003, 0.014, 0.055), Vector3(0.0215, 0.040, -0.040), poly)           # ejection port
	kit.tube(0.005, 0.005, 0.024, Vector3(0.030, 0.050, -0.090), bright, false, 8, Vector3(0, 0, PI * 0.5))   # charging knob
	kit.box(Vector3(0.0355, 0.0035, 0.150), Vector3(0, 0.002, -0.070), glow)              # cold accent line
	kit.box(Vector3(0.032, 0.150, 0.042), Vector3(0, -0.085, -0.095), steel)              # straight magazine
	for i: int in 4:
		kit.box(Vector3(0.0335, 0.004, 0.044), Vector3(0, -0.040 - i * 0.030, -0.095), bright)
	kit.box(Vector3(0.036, 0.008, 0.048), Vector3(0, -0.164, -0.095), bright)             # floor plate
	kit.box(Vector3(0.036, 0.030, 0.050), Vector3(0, -0.012, -0.095), poly)               # magazine well
	kit.box(Vector3(0.012, 0.004, 0.066), Vector3(0, -0.038, -0.030), poly)               # guard
	kit.box(Vector3(0.012, 0.030, 0.004), Vector3(0, -0.022, -0.062), poly)
	kit.box(Vector3(0.005, 0.022, 0.006), Vector3(0, -0.018, -0.026), bright, Vector3(0.35, 0, 0))
	kit.base = Transform3D(Basis(Vector3.RIGHT, -0.26), Vector3(0, -0.004, 0.030))
	kit.box(Vector3(0.030, 0.100, 0.046), Vector3(0, -0.050, 0), poly)                    # grip
	for i: int in 5:
		kit.box(Vector3(0.032, 0.004, 0.040), Vector3(0, -0.022 - i * 0.015, 0), Mats.rubber())
	kit.base = Transform3D.IDENTITY
	# Folded wire stock along the right side.
	for y: float in [0.046, 0.010]:
		kit.tube(0.0045, 0.0045, 0.200, Vector3(0.026, y, 0.030), bright, true, 8)
	kit.box(Vector3(0.010, 0.060, 0.012), Vector3(0.026, 0.028, 0.132), poly)
	kit.box(Vector3(0.006, 0.014, 0.020), Vector3(-0.022, 0.030, 0.070), bright)          # sling loop
