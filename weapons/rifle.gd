class_name Rifle
extends Gun
## AK-47. Thirty rounds, fully automatic: hold the trigger.

const LENGTH_FIX: float = 0.85


static func create(rounds: int = -1) -> Rifle:
	var r := Rifle.new()
	r.kind = &"rifle"
	r.name = "AK47"
	r.capacity = T.rifle_ammo
	r.ammo = T.rifle_ammo if rounds < 0 else rounds
	r.cooldown = T.rifle_cooldown
	r.automatic = true
	r.spread_deg = T.rifle_spread_deg
	r.two_handed = true
	r.muzzle_local = Vector3(0, 0.038, -0.60 * LENGTH_FIX)
	r.hold_offset = Vector3(-0.015, 0.0, 0.02)
	r.burst_strength = 0.16
	r.kick = 0.022
	r.enemy_burst = T.rifle_enemy_burst
	r.enemy_burst_gap = 0.13
	r.blunt_damage = 2
	r.drop_ammo = T.rifle_drop_ammo
	r.enemy_range = T.dude_engage_dist + 4.0
	return r


func mesh_key() -> StringName:
	return &"ak47"


func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.parkerized()
	var bright: Material = Mats.steel()
	var dark: Material = Mats.polymer()
	var wood: Material = Mats.wood()
	var grain: Material = Mats.wood_dark()
	var grip: Material = Mats.bakelite()
	var axis: float = 0.038   # height of the bore
	# Modelled a little long. A real AK-47 is 87 cm from butt plate to muzzle.
	kit.root = Transform3D(Basis.from_scale(Vector3(1, 1, LENGTH_FIX)), Vector3.ZERO)

	# --- receiver: stamped body, trunnion, lower rail lip, rivets
	kit.box(Vector3(0.036, 0.050, 0.265), Vector3(0, 0.018, -0.010), steel)
	kit.box(Vector3(0.040, 0.030, 0.050), Vector3(0, 0.030, -0.130), steel)            # front trunnion
	kit.box(Vector3(0.040, 0.034, 0.040), Vector3(0, 0.024, 0.118), steel)             # rear trunnion
	kit.box(Vector3(0.0385, 0.004, 0.235), Vector3(0, -0.006, -0.010), steel)          # lower lip
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.145, -0.115, -0.060, 0.030, 0.095, 0.125]:
			kit.tube(0.0032, 0.0032, 0.003, Vector3(0.0185 * side, 0.026, z), bright, false, 8, Vector3(0, 0, PI * 0.5))
		kit.box(Vector3(0.0015, 0.010, 0.030), Vector3(0.0188 * side, 0.010, -0.045), steel)   # magazine dimple
		kit.box(Vector3(0.0015, 0.006, 0.150), Vector3(0.0188 * side, 0.040, 0.000), steel)    # pressed rail

	# --- dust cover: ribbed, slightly narrower, with the rear latch
	kit.box(Vector3(0.033, 0.018, 0.225), Vector3(0, 0.052, 0.010), steel)
	kit.box(Vector3(0.026, 0.006, 0.215), Vector3(0, 0.063, 0.010), steel)
	for i: int in 7:
		kit.box(Vector3(0.0335, 0.0185, 0.005), Vector3(0, 0.052, -0.080 + i * 0.030), dark)
	kit.box(Vector3(0.012, 0.010, 0.012), Vector3(0, 0.060, 0.128), bright)            # cover latch button

	# --- bolt carrier, ejection port and charging handle (right side)
	kit.box(Vector3(0.003, 0.016, 0.085), Vector3(0.0180, 0.046, -0.050), dark)        # port
	kit.box(Vector3(0.006, 0.012, 0.060), Vector3(0.0175, 0.046, -0.040), bright)      # carrier face
	kit.tube(0.0055, 0.0045, 0.030, Vector3(0.034, 0.046, -0.020), bright, false, 8, Vector3(0, 0, PI * 0.5))
	kit.ball(0.0062, Vector3(0.049, 0.046, -0.020), bright)

	# --- selector lever: long stamped plate with its pivot and stop (right side)
	kit.box(Vector3(0.002, 0.012, 0.115), Vector3(0.0198, 0.022, 0.020), bright, Vector3(0.10, 0, 0))
	kit.tube(0.007, 0.007, 0.004, Vector3(0.0205, 0.028, 0.074), bright, false, 10, Vector3(0, 0, PI * 0.5))
	kit.box(Vector3(0.004, 0.006, 0.012), Vector3(0.0205, 0.012, -0.036), bright)      # thumb tab

	# --- rear sight: block, tangent leaf, slider and notch
	kit.box(Vector3(0.030, 0.022, 0.058), Vector3(0, 0.068, -0.128), steel)
	kit.box(Vector3(0.012, 0.005, 0.085), Vector3(0, 0.083, -0.120), steel, Vector3(-0.06, 0, 0))
	kit.box(Vector3(0.018, 0.008, 0.010), Vector3(0, 0.086, -0.105), bright)
	kit.box(Vector3(0.005, 0.010, 0.004), Vector3(-0.006, 0.092, -0.083), steel)
	kit.box(Vector3(0.005, 0.010, 0.004), Vector3(0.006, 0.092, -0.083), steel)

	# --- handguards: laminated wood, lower with finger swell and vents, upper over the gas tube
	kit.box(Vector3(0.044, 0.038, 0.170), Vector3(0, 0.012, -0.245), wood)
	kit.box(Vector3(0.050, 0.022, 0.085), Vector3(0, 0.004, -0.255), wood)             # palm swell
	kit.box(Vector3(0.046, 0.012, 0.010), Vector3(0, 0.014, -0.160), steel)            # rear retainer
	kit.box(Vector3(0.047, 0.042, 0.012), Vector3(0, 0.014, -0.334), steel)            # front retainer
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			kit.box(Vector3(0.002, 0.006, 0.026), Vector3(0.0225 * side, 0.024, -0.200 - i * 0.040), dark)   # vents
		for i: int in 4:
			kit.box(Vector3(0.0015, 0.034, 0.003), Vector3(0.0226 * side, 0.012, -0.180 - i * 0.042), grain)  # laminate lines
	kit.box(Vector3(0.036, 0.026, 0.150), Vector3(0, 0.060, -0.240), wood)             # upper handguard
	kit.box(Vector3(0.030, 0.006, 0.140), Vector3(0, 0.075, -0.240), wood)
	for i: int in 3:
		kit.box(Vector3(0.0365, 0.004, 0.004), Vector3(0, 0.070, -0.195 - i * 0.045), grain)
	kit.tube(0.0115, 0.0115, 0.060, Vector3(0, 0.062, -0.345), steel)                  # gas tube, exposed end

	# --- barrel group: barrel, gas block with port and sling loop, front sight tower, muzzle
	kit.tube(0.0088, 0.0098, 0.330, Vector3(0, axis, -0.420), steel)
	kit.box(Vector3(0.024, 0.044, 0.034), Vector3(0, 0.050, -0.385), steel, Vector3(0.30, 0, 0))   # gas block
	kit.tube(0.0125, 0.0125, 0.030, Vector3(0, axis, -0.385), steel)
	kit.box(Vector3(0.004, 0.018, 0.020), Vector3(-0.015, 0.030, -0.385), bright)      # sling loop
	kit.tube(0.0030, 0.0030, 0.300, Vector3(0, 0.018, -0.440), bright)                 # cleaning rod
	kit.box(Vector3(0.010, 0.010, 0.016), Vector3(0, 0.022, -0.512), steel)            # bayonet lug
	kit.tube(0.0135, 0.0135, 0.036, Vector3(0, axis, -0.530), steel)                   # sight base sleeve
	kit.box(Vector3(0.016, 0.052, 0.020), Vector3(0, 0.072, -0.530), steel)            # sight tower
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.003, 0.024, 0.018), Vector3(0.0105 * side, 0.104, -0.530), steel, Vector3(0, 0, -0.25 * side))  # ears
	kit.tube(0.0016, 0.0020, 0.020, Vector3(0, 0.104, -0.530), bright, false, 6)       # sight post
	kit.tube(0.0120, 0.0110, 0.040, Vector3(0, axis, -0.575), steel)                   # slant brake body
	kit.box(Vector3(0.026, 0.006, 0.030), Vector3(0, 0.046, -0.588), steel, Vector3(0.55, 0, 0))   # slant cut lip
	kit.tube(0.0056, 0.0056, 0.006, Vector3(0, axis, -0.596), dark)                    # the bore

	# --- magazine: curved steel box made of six ribbed segments, plus floor plate and catch
	# Each segment sits lower, further forward and tilted a little more than the last: the banana curve.
	for i: int in 6:
		var angle: float = 0.02 + i * 0.105
		var at := Vector3(0, -0.030 - i * 0.034, -0.060 - i * i * 0.0028)
		kit.box(Vector3(0.028, 0.038, 0.066), at, steel, Vector3(angle, 0, 0))
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(0.002, 0.030, 0.006), at + Vector3(0.0148 * side, 0, -0.018), bright, Vector3(angle, 0, 0))
			kit.box(Vector3(0.002, 0.030, 0.006), at + Vector3(0.0148 * side, 0, 0.014), bright, Vector3(angle, 0, 0))
	kit.box(Vector3(0.031, 0.006, 0.072), Vector3(0, -0.238, -0.136), bright, Vector3(0.58, 0, 0))   # floor plate
	kit.box(Vector3(0.010, 0.030, 0.006), Vector3(0, -0.028, -0.010), bright, Vector3(0.25, 0, 0))   # magazine catch

	# --- trigger group
	kit.box(Vector3(0.012, 0.004, 0.070), Vector3(0, -0.048, 0.030), steel)
	kit.box(Vector3(0.012, 0.040, 0.004), Vector3(0, -0.028, -0.004), steel)
	kit.box(Vector3(0.005, 0.026, 0.006), Vector3(0, -0.022, 0.036), bright, Vector3(0.40, 0, 0))

	# --- pistol grip: raked bakelite with a steel cap and chequer lines
	kit.base = Transform3D(Basis(Vector3.RIGHT, -0.30), Vector3(0, -0.010, 0.082))
	kit.box(Vector3(0.030, 0.105, 0.046), Vector3(0, -0.052, 0), grip)
	kit.box(Vector3(0.033, 0.030, 0.050), Vector3(0, -0.092, 0.002), grip)             # flared heel
	kit.box(Vector3(0.0335, 0.005, 0.052), Vector3(0, -0.108, 0.002), bright)
	for side: float in [-1.0, 1.0]:
		for i: int in 6:
			kit.box(Vector3(0.0015, 0.003, 0.038), Vector3(0.0156 * side, -0.020 - i * 0.012, 0), grain)
	kit.base = Transform3D.IDENTITY

	# --- stock: laminated wood, dropped comb, grain lines, steel butt plate with trap, sling swivel
	kit.base = Transform3D(Basis(Vector3.RIGHT, 0.10), Vector3(0, 0.022, 0.135))
	kit.box(Vector3(0.032, 0.046, 0.090), Vector3(0, 0.000, 0.040), wood)              # wrist
	kit.box(Vector3(0.034, 0.066, 0.110), Vector3(0, -0.008, 0.135), wood)
	kit.box(Vector3(0.035, 0.088, 0.100), Vector3(0, -0.017, 0.235), wood)
	kit.box(Vector3(0.028, 0.010, 0.230), Vector3(0, 0.026, 0.160), wood)              # comb
	for side: float in [-1.0, 1.0]:
		for i: int in 4:
			kit.box(Vector3(0.0015, 0.0035, 0.215), Vector3(0.0180 * side, 0.010 - i * 0.017, 0.170), grain, Vector3(-0.04, 0, 0))
	kit.box(Vector3(0.037, 0.094, 0.006), Vector3(0, -0.017, 0.288), bright)           # butt plate
	kit.tube(0.009, 0.009, 0.003, Vector3(0, -0.005, 0.292), steel)                    # cleaning kit trap
	kit.box(Vector3(0.004, 0.020, 0.024), Vector3(-0.021, -0.050, 0.215), bright)      # sling swivel
	kit.base = Transform3D.IDENTITY
