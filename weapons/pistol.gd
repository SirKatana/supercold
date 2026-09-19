class_name Pistol
extends Pickup
## Six rounds. The cooldown runs on world time, so you must let time pass to fire again.

signal ammo_changed(ammo: int)

var ammo: int = 6
var cooldown_left: float = 0.0


static func create(rounds: int = -1) -> Pistol:
	var p := Pistol.new()
	p.kind = &"pistol"
	p.name = "Pistol"
	p.ammo = T.pistol_ammo if rounds < 0 else rounds
	return p


## Modelled from primitives, -Z is the muzzle. Slide, barrel, sights, ejection port,
## serrations, frame and rail, trigger and guard, raked grip with panels, magazine, hammer.
func _build_mesh(root: Node3D) -> void:
	var metal: Material = Mats.gunmetal()
	var steel: Material = Mats.steel()
	var poly: Material = Mats.polymer()
	var panel: Material = Mats.grip_panel()
	var glow: Material = Mats.accent()

	# Slide and what sits on it.
	add_box(root, Vector3(0.034, 0.038, 0.235), Vector3(0, 0.046, -0.058), metal)
	add_box(root, Vector3(0.028, 0.006, 0.20), Vector3(0, 0.067, -0.058), metal)      # top flat
	add_box(root, Vector3(0.018, 0.0045, 0.045), Vector3(0.007, 0.0705, -0.055), steel)  # ejection port
	for i: int in 6:                                                                   # rear serrations
		add_box(root, Vector3(0.0365, 0.030, 0.0035), Vector3(0, 0.046, 0.020 + i * 0.0075), poly)
	for i: int in 3:                                                                   # front serrations
		add_box(root, Vector3(0.0365, 0.026, 0.0035), Vector3(0, 0.046, -0.150 + i * 0.0075), poly)
	add_box(root, Vector3(0.005, 0.009, 0.010), Vector3(0, 0.0745, -0.165), glow)        # front sight
	add_box(root, Vector3(0.006, 0.009, 0.008), Vector3(-0.010, 0.0745, 0.050), poly)    # rear sight
	add_box(root, Vector3(0.006, 0.009, 0.008), Vector3(0.010, 0.0745, 0.050), poly)
	add_box(root, Vector3(0.0355, 0.0035, 0.13), Vector3(0, 0.030, -0.085), glow)        # cold accent line

	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.0085
	barrel_mesh.bottom_radius = 0.0085
	barrel_mesh.height = 0.03
	barrel_mesh.radial_segments = 10
	barrel_mesh.material = steel
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0, 0.048, -0.182)
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(barrel)

	# Frame, rail, trigger group.
	add_box(root, Vector3(0.030, 0.024, 0.195), Vector3(0, 0.016, -0.048), poly)
	add_box(root, Vector3(0.024, 0.009, 0.070), Vector3(0, 0.000, -0.118), poly)        # accessory rail
	for i: int in 3:
		add_box(root, Vector3(0.026, 0.004, 0.006), Vector3(0, -0.0045, -0.140 + i * 0.020), metal)
	add_box(root, Vector3(0.011, 0.005, 0.062), Vector3(0, -0.032, -0.030), poly)        # guard bottom
	add_box(root, Vector3(0.011, 0.034, 0.005), Vector3(0, -0.015, -0.0605), poly)       # guard front
	var trigger: MeshInstance3D = add_box(root, Vector3(0.006, 0.024, 0.006), Vector3(0, -0.012, -0.024), steel)
	trigger.rotation.x = 0.35
	add_box(root, Vector3(0.0315, 0.006, 0.012), Vector3(0, 0.010, -0.010), steel)       # slide stop
	add_box(root, Vector3(0.020, 0.010, 0.028), Vector3(0, 0.024, 0.066), poly)          # beavertail
	add_box(root, Vector3(0.008, 0.016, 0.010), Vector3(0, 0.056, 0.066), steel)         # hammer

	# Raked grip, its panels and grooves, and the magazine base plate.
	var grip := Node3D.new()
	grip.position = Vector3(0, 0.004, 0.030)
	grip.rotation.x = -0.24
	root.add_child(grip)
	add_box(grip, Vector3(0.030, 0.112, 0.050), Vector3(0, -0.058, 0.0), poly)
	for side: float in [-1.0, 1.0]:
		add_box(grip, Vector3(0.004, 0.084, 0.040), Vector3(0.0165 * side, -0.056, 0.0), panel)
		for i: int in 5:
			add_box(grip, Vector3(0.0055, 0.004, 0.036), Vector3(0.0170 * side, -0.026 - i * 0.015, 0.0), poly)
	add_box(grip, Vector3(0.033, 0.009, 0.056), Vector3(0, -0.118, 0.002), steel)
	add_box(grip, Vector3(0.0315, 0.070, 0.006), Vector3(0, -0.060, -0.027), metal)      # front strap


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - TimeManager.world_delta(delta))
	super(delta)


func can_fire() -> bool:
	return ammo > 0 and cooldown_left <= 0.0


func muzzle_position() -> Vector3:
	return global_transform * Vector3(0, 0.048, -0.20)


## `spend` is false for enemies, who never run dry.
func fire(origin: Vector3, direction: Vector3, shooter: Node, spend: bool = true) -> bool:
	if not can_fire():
		return false
	if spend:
		ammo -= 1
		ammo_changed.emit(ammo)
	cooldown_left = T.pistol_cooldown
	BulletPool.for_node(self).fire(origin, direction, shooter)
	Sfx.play(&"shot", origin)
	if spend:
		Game.emit_noise(origin, T.dude_hearing)
	return true
