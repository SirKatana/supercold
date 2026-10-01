class_name WaterBucket
extends Pickup
## A steel bucket of water. Left click pours it out in front of you: any dude it lands on goes
## straight down, and the puddle it leaves makes anyone who runs through it slip for the next
## minute and a half. Thrown full, it does the same where it lands. Empty, it is just a bucket.

signal poured(spill: Puddle)

var full: bool = true

var _water: MeshInstance3D


static func create() -> WaterBucket:
	var b := WaterBucket.new()
	b.kind = &"bucket"
	b.name = "WaterBucket"
	b.blunt_damage = 1
	# By the bail: its wooden grip is at y 0.375 in the model, so the pail hangs under the fist
	# rather than being carried by thin air halfway up its side.
	b.hold_offset = Vector3(0.0, -0.375, 0.02)
	b.hold_euler = Vector3(0.0, 0.0, 0.0)
	return b


func carry_state() -> Dictionary:
	return {"kind": kind, "full": full}


func apply_carry_state(state: Dictionary) -> void:
	full = bool(state.get("full", full))


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"water_bucket", _model)
	root.add_child(mi)
	_water = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.118
	disc.bottom_radius = 0.118
	disc.height = 0.006
	disc.radial_segments = 18
	disc.material = Mats.water()
	_water.mesh = disc
	_water.position.y = 0.205
	root.add_child(_water)
	_water.visible = full


## Galvanised pail: tapered sides (an outer and an inner skin, so it is hollow), rolled rim, base
## ring, two ears and a wire bail handle with a wooden grip.
static func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.steel()
	var dark: Material = Mats.gunmetal()
	var wood: Material = Mats.wood()
	var outer := CylinderMesh.new()
	outer.top_radius = 0.130
	outer.bottom_radius = 0.095
	outer.height = 0.240
	outer.radial_segments = 18
	outer.cap_top = false
	kit.add(outer, Transform3D(Basis.IDENTITY, Vector3(0, 0.120, 0)), steel)
	var inner := CylinderMesh.new()
	inner.top_radius = 0.124
	inner.bottom_radius = 0.090
	inner.height = 0.232
	inner.radial_segments = 18
	inner.cap_top = false
	inner.flip_faces = true
	kit.add(inner, Transform3D(Basis.IDENTITY, Vector3(0, 0.124, 0)), dark)
	var rim := TorusMesh.new()                                                 # rolled rim: a ring, the top stays open
	rim.inner_radius = 0.124
	rim.outer_radius = 0.138
	rim.rings = 18
	rim.ring_segments = 6
	kit.add(rim, Transform3D(Basis.IDENTITY, Vector3(0, 0.240, 0)), steel)
	kit.tube(0.099, 0.099, 0.014, Vector3(0, 0.007, 0), dark, false, 18)       # base ring
	for y: float in [0.085, 0.165]:                                            # strengthening ribs
		kit.tube(0.096 + y * 0.146 + 0.003, 0.096 + y * 0.146 + 0.003, 0.006, Vector3(0, y, 0), dark, false, 18)
	for side: float in [-1.0, 1.0]:                                            # ears
		kit.box(Vector3(0.010, 0.030, 0.026), Vector3(0.136 * side, 0.225, 0), dark)
	# Bail handle: an arc of short wire segments over the top, with a grip in the middle.
	for i: int in 9:
		var a: float = PI * (i + 0.5) / 9.0
		var at := Vector3(cos(a) * 0.136, 0.225 + sin(a) * 0.150, 0)
		kit.tube(0.004, 0.004, 0.052, at, steel, false, 6, Vector3(0, 0, a + PI * 0.5 - PI * 0.5))
	kit.tube(0.011, 0.011, 0.085, Vector3(0, 0.375, 0), wood, false, 10, Vector3(0, 0, PI * 0.5))


func _set_full(now: bool) -> void:
	full = now
	if _water != null:
		_water.visible = now


## Tips the bucket out in front of the player. False if it was already empty.
func pour(player: Player) -> bool:
	if not full:
		return false
	var from: Vector3 = player.aim_origin()
	var forward: Vector3 = player.aim_direction()
	var flat := Vector3(forward.x, 0, forward.z).normalized()
	# The water lands where you are looking, but never further than you could fling it.
	var reach: float = T.pour_reach
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * (T.pour_reach + 1.5), 1 | 32)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		reach = minf(reach, maxf(0.8, from.distance_to(hit["position"]) - 0.4))
	var landing: Vector3 = player.global_position + flat * reach
	splash(landing, flat)
	return true


## Water hits the floor at `at`: a splash, a spill, and anyone standing in it goes over.
func splash(at: Vector3, direction: Vector3) -> Puddle:
	_set_full(false)
	var world: Node = Game.entities_root(self)
	var spill := Puddle.new()
	spill.name = "Spill"
	spill.radius = T.spill_radius
	spill.life = T.spill_seconds
	world.add_child(spill)
	spill.global_position = Vector3(at.x, 0.0, at.z)
	Game.report_spill(spill)
	Shatter.burst(world, Vector3(at.x, 0.4, at.z), 26, Mats.splash(), Vector3(0.9, 0.2, 0.9), direction * 2.5 + Vector3.UP * 1.5, 0.07)
	Sfx.play(&"splash", at)
	Game.emit_noise(at, T.dude_hearing * 0.6)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude != null and dude.alive and Vector2(dude.global_position.x - at.x, dude.global_position.z - at.z).length() <= T.spill_radius:
			# Soaked where he stands. He does not need to be running for this one.
			var away: Vector3 = dude.global_position - at
			dude.slip(away if away.length() > 0.3 else direction)
	poured.emit(spill)
	return spill


## Thrown full, it empties where it lands.
func _on_flight_hit(collider: Object, point: Vector3, normal: Vector3) -> void:
	if full and dangerous:
		splash(point, velocity.normalized())
	super(collider, point, normal)
