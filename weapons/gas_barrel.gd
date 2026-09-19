class_name GasBarrel
extends Pickup
## Red gas barrel with a flammable warning. A bullet, a thrown impact or a nearby blast sets
## it off. It stands solid on the floor, and it can be picked up and thrown.

const RADIUS: float = 0.29
const HEIGHT: float = 0.88

var exploded: bool = false

var _fuse: float = -1.0
var _solid: StaticBody3D


static func create() -> GasBarrel:
	var b := GasBarrel.new()
	b.kind = &"barrel"
	b.name = "GasBarrel"
	b.blunt_damage = 0
	b.hold_offset = Vector3(0.02, -0.62, -0.30)
	b.throw_speed_scale = T.barrel_throw_speed / T.throw_speed
	return b


func _make_shape() -> Shape3D:
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS + 0.03
	shape.height = HEIGHT
	return shape


func _shape_offset() -> Vector3:
	return Vector3(0, HEIGHT * 0.5, 0)


func _ready() -> void:
	add_to_group(&"barrels")
	# What you bump into. The Area3D around it is what bullets and hands find.
	_solid = StaticBody3D.new()
	_solid.collision_layer = 1
	_solid.collision_mask = 0
	var solid_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	solid_shape.shape = cylinder
	solid_shape.position.y = HEIGHT * 0.5
	_solid.add_child(solid_shape)
	add_child(_solid)
	super()


func _apply_layer() -> void:
	super()
	if state != State.HELD:
		collision_layer |= 32      # breakables: bullets and punches reach it even at rest
	if _solid != null:
		(_solid.get_child(0) as CollisionShape3D).disabled = state != State.RESTING


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"gas_barrel", _model)
	root.add_child(mi)
	for facing: float in [0.0, PI]:
		var label := Label3D.new()
		label.text = "FLAMMABLE\nGAS"
		label.font_size = 28
		label.pixel_size = 0.0019
		label.outline_size = 6
		label.outline_modulate = Color(0, 0, 0)
		label.modulate = Color(1, 1, 1)
		label.shaded = false
		label.line_spacing = -6.0
		label.position = Vector3(0, 0.235, 0).rotated(Vector3.UP, facing) + Vector3(0, 0, RADIUS + 0.012).rotated(Vector3.UP, facing)
		label.rotation.y = facing
		root.add_child(label)


static func _model(kit: MeshKit) -> void:
	var red: Material = Mats.barrel_red()
	var steel: Material = Mats.steel()
	var black: Material = Mats.rubber()
	var yellow: Material = Mats.hazard_yellow()
	var white: Material = Mats.white_paint()

	kit.tube(RADIUS, RADIUS, HEIGHT, Vector3(0, HEIGHT * 0.5, 0), red, false, 20)
	for y: float in [0.03, HEIGHT * 0.34, HEIGHT * 0.66, HEIGHT - 0.03]:                  # rolling hoops and chimes
		kit.tube(RADIUS + 0.014, RADIUS + 0.014, 0.035, Vector3(0, y, 0), red, false, 20)
	kit.tube(RADIUS - 0.02, RADIUS - 0.02, 0.012, Vector3(0, HEIGHT - 0.012, 0), steel, false, 20)   # recessed lid
	kit.tube(0.045, 0.045, 0.030, Vector3(0.13, HEIGHT + 0.004, 0.05), steel, false, 10)   # large bung
	kit.tube(0.022, 0.022, 0.026, Vector3(-0.15, HEIGHT + 0.004, -0.04), steel, false, 8)  # vent bung
	kit.tube(RADIUS + 0.004, RADIUS + 0.004, 0.10, Vector3(0, HEIGHT * 0.17, 0), white, false, 20)   # white band
	kit.tube(RADIUS + 0.005, RADIUS + 0.005, 0.016, Vector3(0, HEIGHT * 0.17 + 0.058, 0), black, false, 20)
	kit.tube(RADIUS + 0.005, RADIUS + 0.005, 0.016, Vector3(0, HEIGHT * 0.17 - 0.058, 0), black, false, 20)

	# Fire warning diamonds, front and back: black border, yellow field, black flame.
	for facing: float in [0.0, PI]:
		kit.base = Transform3D(Basis(Vector3.UP, facing), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT * 0.60, RADIUS + 0.004))
		kit.box(Vector3(0.235, 0.235, 0.006), Vector3.ZERO, black, Vector3(0, 0, PI * 0.25))
		kit.box(Vector3(0.205, 0.205, 0.008), Vector3(0, 0, 0.002), yellow, Vector3(0, 0, PI * 0.25))
		# The flame: a tall centre tongue, a lower one each side, and a rounded base.
		var tongues: Array = [[0.0, 0.004, 0.050, 0.150, 0.0], [-0.036, -0.022, 0.034, 0.090, 0.28], [0.036, -0.026, 0.032, 0.082, -0.30]]
		for t: Array in tongues:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = t[2]
			cone.height = t[3]
			cone.radial_segments = 10
			cone.rings = 0
			kit.add(cone, Transform3D(Basis(Vector3.BACK, t[4]) * Basis.from_scale(Vector3(1, 1, 0.12)), Vector3(t[0], t[1] + t[3] * 0.5 - 0.055, 0.008)), black)
		kit.ball(0.052, Vector3(0, -0.052, 0.008), black, Vector3(1.15, 0.8, 0.12))
		kit.box(Vector3(0.12, 0.010, 0.004), Vector3(0, -0.090, 0.008), black)               # ground line
	kit.base = Transform3D.IDENTITY


func _physics_process(delta: float) -> void:
	if _fuse >= 0.0:
		_fuse -= TimeManager.world_delta(delta)
		if _fuse < 0.0:
			explode()
			return
	super(delta)


func on_bullet_hit(_bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	explode()


## A thrown barrel goes off on whatever it hits first.
func _on_flight_hit(collider: Object, point: Vector3, normal: Vector3) -> void:
	if dangerous:
		global_position = point + normal * 0.1
		explode()
		return
	super(collider, point, normal)


## Lit by a neighbouring blast. Goes off after `delay` world seconds.
func cook_off(delay: float) -> void:
	if not exploded and _fuse < 0.0:
		_fuse = maxf(0.0, delay)


func explode() -> void:
	if exploded:
		return
	exploded = true
	var centre: Vector3 = global_position + Vector3.UP * (HEIGHT * 0.5 if state == State.RESTING else 0.0)
	Explosion.detonate(Game.entities_root(self), centre, self)
	queue_free()
