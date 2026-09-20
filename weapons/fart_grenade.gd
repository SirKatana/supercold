class_name FartGrenade
extends Pickup
## Stink grenade. Throw it and where it lands a bank of green fog rolls out to fill the room.
## Every dude who stays in it grabs his throat, doubles over, gags and drops. Gas masks
## (shield troopers), biters and bosses are immune. A bullet sets it off where it lies.

var gone_off: bool = false


static func create() -> FartGrenade:
	var g := FartGrenade.new()
	g.kind = &"fart"
	g.name = "FartGrenade"
	g.blunt_damage = 0
	g.hold_offset = Vector3(0.0, 0.02, -0.04)
	return g


func is_weapon() -> bool:
	return true


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"fart_grenade", _model)
	root.add_child(mi)


## A squat olive canister: green gas band, vent holes, fuze head with pin ring and safety lever,
## and three wavy stink lines painted on the side.
static func _model(kit: MeshKit) -> void:
	var body: Material = Mats.grenade_olive()
	var steel: Material = Mats.steel()
	var dark: Material = Mats.polymer()
	var gas: Material = Mats.fart_glow()
	kit.tube(0.046, 0.046, 0.120, Vector3.ZERO, body, false, 16)                       # canister
	kit.tube(0.040, 0.046, 0.016, Vector3(0, 0.068, 0), body, false, 16)               # shoulder
	kit.tube(0.046, 0.040, 0.014, Vector3(0, -0.067, 0), body, false, 16)              # base chamfer
	kit.tube(0.0475, 0.0475, 0.026, Vector3(0, 0.018, 0), gas, false, 16)              # glowing green band
	kit.tube(0.0478, 0.0478, 0.006, Vector3(0, 0.035, 0), dark, false, 16)
	kit.tube(0.0478, 0.0478, 0.006, Vector3(0, 0.001, 0), dark, false, 16)
	for i: int in 8:                                                                    # vent holes round the top
		var a: float = i * TAU / 8.0
		kit.tube(0.0055, 0.0055, 0.004, Vector3(cos(a) * 0.030, 0.0775, sin(a) * 0.030), dark, false, 8)
	kit.tube(0.018, 0.022, 0.030, Vector3(0, 0.091, 0), steel, false, 12)              # fuze head
	kit.tube(0.010, 0.010, 0.012, Vector3(0, 0.112, 0), dark, false, 10)               # striker cap
	kit.box(Vector3(0.014, 0.004, 0.060), Vector3(0.012, 0.104, 0.026), steel, Vector3(0.95, 0, 0))   # lever, top
	kit.box(Vector3(0.014, 0.090, 0.004), Vector3(0.012, 0.030, 0.052), steel)                          # lever, down the side
	var ring := TorusMesh.new()                                                         # pull ring
	ring.inner_radius = 0.013
	ring.outer_radius = 0.017
	ring.rings = 14
	ring.ring_segments = 6
	kit.add(ring, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.034, 0.098, 0)), steel)
	kit.tube(0.0025, 0.0025, 0.030, Vector3(-0.012, 0.098, 0), steel, false, 6, Vector3(0, 0, PI * 0.5))   # pin
	for i: int in 3:                                                                    # stink lines, front and back
		for side: float in [-1.0, 1.0]:
			for seg: int in 4:
				var sway: float = 0.007 if seg % 2 == 0 else -0.007
				kit.box(Vector3(0.005, 0.014, 0.002), Vector3(-0.020 + i * 0.020 + sway, -0.045 + seg * 0.013, 0.0468 * side), gas,
					Vector3(0, 0, 0.5 if seg % 2 == 0 else -0.5))


## Layer 6 too, so a bullet can set it off where it lies.
func _apply_layer() -> void:
	super()
	if state != State.HELD:
		collision_layer |= 32


func on_bullet_hit(_bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	go_off()


func _on_flight_hit(collider: Object, point: Vector3, normal: Vector3) -> void:
	if dangerous:
		global_position = point + normal * 0.15
		go_off()
		return
	super(collider, point, normal)


## Pops, and the fog rolls out from here. Returns the cloud.
func go_off() -> FartCloud:
	if gone_off:
		return null
	gone_off = true
	var cloud: FartCloud = FartCloud.release(Game.entities_root(self), global_position)
	Shatter.burst(Game.entities_root(self), global_position, 8, Mats.grenade_olive(), Vector3.ONE * 0.04, Vector3.UP * 2.0, 0.045)
	queue_free()
	return cloud
