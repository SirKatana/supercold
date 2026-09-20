class_name Revolver
extends Gun
## Heavy revolver. Five rounds, slow, kicks like a mule, and each round goes through two dudes.


static func create(rounds: int = -1) -> Revolver:
	var g := Revolver.new()
	g.kind = &"revolver"
	g.name = "Revolver"
	g.capacity = T.revolver_ammo
	g.ammo = T.revolver_ammo if rounds < 0 else rounds
	g.cooldown = T.revolver_cooldown
	g.pierce = T.revolver_pierce
	g.bullet_scale = 1.25
	g.bullet_speed_scale = 1.35
	g.muzzle_local = Vector3(0, 0.052, -0.26)
	g.burst_strength = 0.30
	g.kick = 0.11
	g.drop_ammo = 3
	return g


func mesh_key() -> StringName:
	return &"revolver"


func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.steel()
	var blued: Material = Mats.gunmetal()
	var wood: Material = Mats.wood()
	var grain: Material = Mats.wood_dark()
	kit.tube(0.0115, 0.0125, 0.165, Vector3(0, 0.052, -0.175), blued, true, 12)           # barrel
	kit.box(Vector3(0.010, 0.010, 0.160), Vector3(0, 0.068, -0.175), blued)               # top rib
	for i: int in 6:
		kit.box(Vector3(0.0105, 0.003, 0.010), Vector3(0, 0.0745, -0.240 + i * 0.026), steel)   # rib vents
	kit.box(Vector3(0.012, 0.014, 0.110), Vector3(0, 0.034, -0.160), blued)               # ejector shroud
	kit.tube(0.0040, 0.0040, 0.030, Vector3(0, 0.034, -0.228), steel, true, 8)            # ejector rod tip
	kit.box(Vector3(0.005, 0.012, 0.012), Vector3(0, 0.082, -0.248), Mats.accent())       # front sight
	kit.tube(0.0062, 0.0062, 0.005, Vector3(0, 0.052, -0.259), Mats.polymer(), true, 10)  # bore
	kit.box(Vector3(0.030, 0.064, 0.090), Vector3(0, 0.040, -0.050), blued)               # frame
	kit.tube(0.0245, 0.0245, 0.058, Vector3(0, 0.046, -0.058), steel, true, 12)           # cylinder
	for i: int in 6:                                                                      # flutes
		var a: float = i * TAU / 6.0
		kit.tube(0.0050, 0.0050, 0.040, Vector3(cos(a) * 0.0235, 0.046 + sin(a) * 0.0235, -0.064), blued, true, 8)
	kit.box(Vector3(0.010, 0.020, 0.014), Vector3(0, 0.086, -0.004), blued)               # rear sight
	kit.box(Vector3(0.008, 0.026, 0.012), Vector3(0, 0.082, 0.020), steel, Vector3(-0.5, 0, 0))   # hammer spur
	kit.box(Vector3(0.012, 0.004, 0.060), Vector3(0, -0.020, -0.030), blued)              # guard
	kit.box(Vector3(0.012, 0.034, 0.004), Vector3(0, -0.004, -0.060), blued)
	kit.box(Vector3(0.005, 0.022, 0.006), Vector3(0, -0.002, -0.028), steel, Vector3(0.35, 0, 0))
	kit.base = Transform3D(Basis(Vector3.RIGHT, -0.34), Vector3(0, 0.012, 0.012))
	kit.box(Vector3(0.026, 0.115, 0.040), Vector3(0, -0.055, 0.004), blued)               # grip frame
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.008, 0.104, 0.048), Vector3(0.015 * side, -0.058, 0.004), wood)   # wooden panels
		for i: int in 6:
			kit.box(Vector3(0.0015, 0.003, 0.040), Vector3(0.0195 * side, -0.020 - i * 0.015, 0.004), grain)
		kit.tube(0.005, 0.005, 0.003, Vector3(0.0195 * side, -0.060, 0.004), Mats.brass(), false, 8, Vector3(0, 0, PI * 0.5))   # medallion
	kit.box(Vector3(0.028, 0.008, 0.050), Vector3(0, -0.116, 0.004), steel)               # butt cap
	kit.base = Transform3D.IDENTITY
