class_name Crossbow
extends Gun
## A quiet crossbow. Four bolts, slow to span, and the bolt goes straight through two dudes.
## Nobody comes running: firing it makes no noise for anyone but the man it hits.


static func create(bolts: int = -1) -> Crossbow:
	var g := Crossbow.new()
	g.kind = &"crossbow"
	g.name = "Crossbow"
	g.capacity = T.crossbow_ammo
	g.ammo = T.crossbow_ammo if bolts < 0 else bolts
	g.cooldown = T.crossbow_cooldown
	g.pierce = T.crossbow_pierce
	g.bullet_speed_scale = T.crossbow_speed_scale
	g.bullet_scale = 1.1
	g.two_handed = true
	g.silent = true
	g.sound = &"stab"
	g.muzzle_local = Vector3(0, 0.055, -0.46)
	g.hold_offset = Vector3(-0.01, -0.02, 0.05)
	g.burst_strength = 0.12
	g.kick = 0.07
	g.drop_ammo = 2
	g.enemy_range = 22.0
	g.enemy_aim_time = 1.1
	g.blunt_damage = 2
	return g


func mesh_key() -> StringName:
	return &"crossbow"


## -Z is down the bolt groove. Stock behind the hand, prod across the front.
func _model(kit: MeshKit) -> void:
	var wood: Material = Mats.wood_dark()
	var steel: Material = Mats.steel()
	var dark: Material = Mats.polymer()
	var cord: Material = Mats.ceramic()
	kit.box(Vector3(0.055, 0.045, 0.70), Vector3(0, 0.0, -0.18), wood)                          # stock
	kit.box(Vector3(0.030, 0.022, 0.60), Vector3(0, 0.034, -0.24), dark)                        # bolt groove
	kit.box(Vector3(0.016, 0.016, 0.34), Vector3(0, 0.046, -0.36), steel)                       # the bolt in it
	kit.box(Vector3(0.030, 0.030, 0.030), Vector3(0, 0.046, -0.53), steel, Vector3(0, PI * 0.25, 0))   # its head
	kit.box(Vector3(0.075, 0.035, 0.075), Vector3(0, -0.02, 0.16), wood, Vector3(-0.22, 0, 0))   # butt
	kit.box(Vector3(0.040, 0.075, 0.050), Vector3(0, -0.07, -0.06), wood, Vector3(-0.30, 0, 0))  # grip
	kit.box(Vector3(0.020, 0.040, 0.018), Vector3(0, -0.035, -0.10), steel)                      # trigger guard
	kit.box(Vector3(0.012, 0.028, 0.010), Vector3(0, -0.038, -0.085), dark)                      # trigger
	# The prod, swept back, with the string across it.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.24, 0.016, 0.022), Vector3(0.14 * side, 0.030, -0.42), steel, Vector3(0, 0.18 * side, 0))
		kit.box(Vector3(0.020, 0.024, 0.020), Vector3(0.265 * side, 0.030, -0.395), dark)         # tip
		kit.box(Vector3(0.28, 0.006, 0.006), Vector3(0.132 * side, 0.030, -0.30), cord, Vector3(0, -0.42 * side, 0))   # string
	kit.box(Vector3(0.050, 0.020, 0.090), Vector3(0, 0.055, -0.40), dark)                        # stirrup bridge
	kit.box(Vector3(0.020, 0.075, 0.020), Vector3(0, 0.020, -0.56), steel, Vector3(0.3, 0, 0))    # stirrup
