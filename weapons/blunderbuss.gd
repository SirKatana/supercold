class_name Blunderbuss
extends Gun
## A gun from the 1800s: a bell-mouthed blunderbuss with a walnut stock, brass furniture and a
## flintlock. One barrel, a fistful of shot, and a very long wait while it is loaded again.
## It kicks hard enough to move the man holding it.


static func create(loads: int = -1) -> Blunderbuss:
	var g := Blunderbuss.new()
	g.kind = &"blunderbuss"
	g.name = "Blunderbuss"
	g.capacity = T.blunderbuss_ammo
	g.ammo = T.blunderbuss_ammo if loads < 0 else loads
	g.cooldown = T.blunderbuss_cooldown
	g.pellets = T.blunderbuss_pellets
	g.spread_deg = T.blunderbuss_spread
	g.bullet_speed_scale = 0.85
	g.bullet_scale = 0.8
	g.two_handed = true
	g.muzzle_local = Vector3(0, 0.055, -0.46)
	g.hold_offset = Vector3(-0.01, -0.01, 0.06)
	g.burst_strength = 0.16
	g.kick = 0.18
	g.drop_ammo = 1
	g.enemy_range = 13.0
	g.enemy_pellets = T.blunderbuss_enemy_pellets
	g.enemy_aim_time = 0.9
	g.blunt_damage = 2
	g.sound = &"shot"
	return g


func mesh_key() -> StringName:
	return &"blunderbuss"


## -Z is the bell. Walnut stock behind the hand, brass bands, a flintlock on the right side.
func _model(kit: MeshKit) -> void:
	var walnut: Material = Mats.wood_dark()
	var brass: Material = Mats.brass()
	var iron: Material = Mats.gunmetal()
	# Barrel: straight, then flaring out to the bell.
	kit.tube(0.030, 0.034, 0.34, Vector3(0, 0.055, -0.18), iron, true, 12)
	kit.tube(0.075, 0.036, 0.16, Vector3(0, 0.055, -0.42), iron, true, 14)          # the flare
	kit.tube(0.082, 0.082, 0.03, Vector3(0, 0.055, -0.50), brass, true, 14)          # the lip of the bell
	kit.tube(0.037, 0.037, 0.03, Vector3(0, 0.055, -0.02), brass, true, 12)          # band
	kit.tube(0.037, 0.037, 0.03, Vector3(0, 0.055, -0.30), brass, true, 12)
	# Stock: fore-end under the barrel, wrist, and a curved butt.
	kit.box(Vector3(0.055, 0.060, 0.34), Vector3(0, 0.012, -0.16), walnut)
	kit.box(Vector3(0.050, 0.075, 0.20), Vector3(0, 0.005, 0.08), walnut)
	kit.box(Vector3(0.048, 0.105, 0.16), Vector3(0, -0.020, 0.24), walnut, Vector3(0.16, 0, 0))
	kit.box(Vector3(0.052, 0.115, 0.03), Vector3(0, -0.030, 0.315), brass, Vector3(0.16, 0, 0))   # butt plate
	kit.box(Vector3(0.046, 0.060, 0.08), Vector3(0, -0.045, 0.02), walnut, Vector3(-0.35, 0, 0))  # grip behind the lock
	# Flintlock: plate, cock, frizzen, pan.
	kit.box(Vector3(0.012, 0.055, 0.12), Vector3(0.032, 0.020, 0.00), iron)
	kit.box(Vector3(0.014, 0.055, 0.020), Vector3(0.038, 0.058, 0.03), iron, Vector3(0.5, 0, 0))  # cock
	kit.box(Vector3(0.012, 0.030, 0.030), Vector3(0.038, 0.055, -0.03), brass, Vector3(-0.4, 0, 0))  # frizzen
	kit.box(Vector3(0.020, 0.010, 0.040), Vector3(0.030, 0.040, -0.01), brass)                    # pan
	kit.box(Vector3(0.010, 0.030, 0.012), Vector3(0.0, -0.030, -0.03), iron)                      # trigger
	kit.box(Vector3(0.014, 0.022, 0.075), Vector3(0.0, -0.048, -0.02), iron)                      # trigger guard
	kit.tube(0.006, 0.006, 0.30, Vector3(0, 0.020, -0.20), walnut, true, 6)                       # ramrod under the barrel
