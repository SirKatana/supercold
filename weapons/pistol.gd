class_name Pistol
extends Gun
## Six rounds, one at a time.


static func create(rounds: int = -1) -> Pistol:
	var p := Pistol.new()
	p.kind = &"pistol"
	p.name = "Pistol"
	p.capacity = T.pistol_ammo
	p.ammo = T.pistol_ammo if rounds < 0 else rounds
	p.cooldown = T.pistol_cooldown
	p.muzzle_local = Vector3(0, 0.048, -0.20)
	p.drop_ammo = T.enemy_drop_ammo
	p.enemy_range = T.dude_engage_dist
	return p


func mesh_key() -> StringName:
	return &"pistol"


## Slide, barrel, sights, ejection port, serrations, frame and rail, trigger and guard,
## raked grip with panels and grooves, magazine plate, hammer.
func _model(kit: MeshKit) -> void:
	var metal: Material = Mats.gunmetal()
	var steel: Material = Mats.steel()
	var poly: Material = Mats.polymer()
	var panel: Material = Mats.grip_panel()
	var glow: Material = Mats.accent()

	kit.box(Vector3(0.034, 0.038, 0.235), Vector3(0, 0.046, -0.058), metal)
	kit.box(Vector3(0.028, 0.006, 0.20), Vector3(0, 0.067, -0.058), metal)
	kit.box(Vector3(0.018, 0.0045, 0.045), Vector3(0.007, 0.0705, -0.055), steel)
	for i: int in 6:
		kit.box(Vector3(0.0365, 0.030, 0.0035), Vector3(0, 0.046, 0.020 + i * 0.0075), poly)
	for i: int in 3:
		kit.box(Vector3(0.0365, 0.026, 0.0035), Vector3(0, 0.046, -0.150 + i * 0.0075), poly)
	kit.box(Vector3(0.005, 0.009, 0.010), Vector3(0, 0.0745, -0.165), glow)
	kit.box(Vector3(0.006, 0.009, 0.008), Vector3(-0.010, 0.0745, 0.050), poly)
	kit.box(Vector3(0.006, 0.009, 0.008), Vector3(0.010, 0.0745, 0.050), poly)
	kit.box(Vector3(0.0355, 0.0035, 0.13), Vector3(0, 0.030, -0.085), glow)
	kit.tube(0.0085, 0.0085, 0.03, Vector3(0, 0.048, -0.182), steel)

	kit.box(Vector3(0.030, 0.024, 0.195), Vector3(0, 0.016, -0.048), poly)
	kit.box(Vector3(0.024, 0.009, 0.070), Vector3(0, 0.000, -0.118), poly)
	for i: int in 3:
		kit.box(Vector3(0.026, 0.004, 0.006), Vector3(0, -0.0045, -0.140 + i * 0.020), metal)
	kit.box(Vector3(0.011, 0.005, 0.062), Vector3(0, -0.032, -0.030), poly)
	kit.box(Vector3(0.011, 0.034, 0.005), Vector3(0, -0.015, -0.0605), poly)
	kit.box(Vector3(0.006, 0.024, 0.006), Vector3(0, -0.012, -0.024), steel, Vector3(0.35, 0, 0))
	kit.box(Vector3(0.0315, 0.006, 0.012), Vector3(0, 0.010, -0.010), steel)
	kit.box(Vector3(0.020, 0.010, 0.028), Vector3(0, 0.024, 0.066), poly)
	kit.box(Vector3(0.008, 0.016, 0.010), Vector3(0, 0.056, 0.066), steel)

	kit.base = Transform3D(Basis(Vector3.RIGHT, -0.24), Vector3(0, 0.004, 0.030))
	kit.box(Vector3(0.030, 0.112, 0.050), Vector3(0, -0.058, 0.0), poly)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.004, 0.084, 0.040), Vector3(0.0165 * side, -0.056, 0.0), panel)
		for i: int in 5:
			kit.box(Vector3(0.0055, 0.004, 0.036), Vector3(0.0170 * side, -0.026 - i * 0.015, 0.0), poly)
	kit.box(Vector3(0.033, 0.009, 0.056), Vector3(0, -0.118, 0.002), steel)
	kit.box(Vector3(0.0315, 0.070, 0.006), Vector3(0, -0.060, -0.027), metal)
	kit.base = Transform3D.IDENTITY
