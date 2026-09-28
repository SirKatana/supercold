class_name CarrotGun
extends Gun
## What they hand the basement guards: a wide orange thing that fires carrots. It is not a joke
## to the man it hits. A carrot kills like any other round, it just travels slower and is easier
## to see coming, which is the only mercy down there.


static func create(rounds: int = -1) -> CarrotGun:
	var g := CarrotGun.new()
	g.kind = &"carrot"
	g.name = "CarrotGun"
	g.capacity = T.carrot_ammo
	g.ammo = T.carrot_ammo if rounds < 0 else rounds
	g.cooldown = T.carrot_cooldown
	g.bullet_speed_scale = T.carrot_speed_scale
	g.bullet_style = &"carrot"
	g.bullet_scale = 1.35
	g.two_handed = true
	g.spread_deg = 2.2
	g.muzzle_local = Vector3(0, 0.05, -0.34)
	g.hold_offset = Vector3(-0.01, -0.01, 0.02)
	g.burst_strength = 0.12
	g.kick = 0.06
	g.drop_ammo = 5
	g.enemy_range = 15.0
	g.enemy_burst = 2
	g.enemy_burst_gap = 0.22
	g.enemy_aim_time = 0.6
	g.blunt_damage = 2
	return g


func mesh_key() -> StringName:
	return &"carrot_gun"


## A hopper of carrots on top, a wide barrel, and a crank on the side. -Z is the muzzle.
func _model(kit: MeshKit) -> void:
	var shell: Material = Mats.carrot()
	var dark: Material = Mats.polymer()
	var steel: Material = Mats.steel()
	var green: Material = Mats.carrot_top()
	kit.tube(0.055, 0.062, 0.38, Vector3(0, 0.05, -0.16), shell, true, 12)          # barrel
	kit.tube(0.068, 0.068, 0.04, Vector3(0, 0.05, -0.33), steel, true, 12)          # muzzle ring
	kit.box(Vector3(0.11, 0.10, 0.26), Vector3(0, 0.04, 0.05), dark)                # body
	kit.box(Vector3(0.09, 0.13, 0.11), Vector3(0, 0.13, 0.04), shell)               # hopper
	for i: int in 4:                                                                # carrots in it
		kit.tube(0.0, 0.016, 0.07, Vector3(-0.025 + i * 0.017, 0.20, 0.02 + (i % 2) * 0.02), shell, false, 8)
		kit.ball(0.014, Vector3(-0.025 + i * 0.017, 0.245, 0.02 + (i % 2) * 0.02), green)
	kit.box(Vector3(0.05, 0.10, 0.05), Vector3(0, -0.05, 0.10), dark, Vector3(-0.30, 0, 0))   # grip
	kit.box(Vector3(0.04, 0.05, 0.16), Vector3(0, -0.02, 0.22), dark, Vector3(0.12, 0, 0))    # stock
	kit.box(Vector3(0.02, 0.04, 0.02), Vector3(0, -0.01, -0.02), steel)             # trigger
	kit.tube(0.035, 0.035, 0.02, Vector3(0.07, 0.04, 0.06), steel, true, 10)        # crank plate
	kit.box(Vector3(0.012, 0.06, 0.012), Vector3(0.085, 0.07, 0.06), steel)         # crank handle
