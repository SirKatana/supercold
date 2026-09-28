class_name Bullet
extends Node3D
## Not a physics body. Each tick it advances on world time and sweeps a ray over
## the distance covered, so it cannot tunnel at any speed or time scale.

signal hit(collider: Object, point: Vector3)
signal deflected(by: Object)

const T: Tuning = preload("res://data/tuning.tres")
const MASK: int = 1 | 2 | 4 | 32 | 64 | 128 | 256  # world, player, enemies, breakables, flying items, shields, allies
const TRAIL_LENGTH: float = 1.8

var active: bool = false
var direction: Vector3 = Vector3.FORWARD
var shooter: Node = null
var age: float = 0.0
## How many more dudes it goes through, and how fast it flies compared to a pistol round.
var pierce_left: int = 0
var speed_scale: float = 1.0
var _passed: Array[RID] = []
var _heavy: bool = false

var _trail: MeshInstance3D
var _body: Node3D
var _travelled: float = 0.0
var _size: float = 1.0

static var _round_mesh: ArrayMesh
static var _carrot_mesh: ArrayMesh
var _round_instance: MeshInstance3D
## What this round looks like: nothing for a bullet, `&"carrot"` for what the basement guards fire.
var style: StringName = &""
static var _trail_mesh: CylinderMesh


func _ready() -> void:
	# One mesh pair shared by every bullet, so spawning one costs two nodes and nothing else.
	if _round_mesh == null:
		_round_mesh = MeshKit.cached(&"bullet", _model_round)
		_trail_mesh = CylinderMesh.new()
		_trail_mesh.top_radius = 0.022     # wide at the bullet
		_trail_mesh.bottom_radius = 0.0    # tapering to nothing behind it
		_trail_mesh.height = 1.0
		_trail_mesh.radial_segments = 6
		_trail_mesh.rings = 0
		_trail_mesh.cap_top = false
		_trail_mesh.cap_bottom = false
		_trail_mesh.material = Mats.pink_trail()
	_body = Node3D.new()
	add_child(_body)
	_round_instance = MeshInstance3D.new()
	_round_instance.mesh = _round_mesh
	_round_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_round_instance)

	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	# The cylinder's top (+Y, the wide end) points at -Z, toward the bullet.
	_trail.rotation.x = -PI * 0.5
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	deactivate()


## A black round that reads as a bullet: ogive nose, bearing surface, crimp groove, boat tail.
## Drawn about three times life size so it can be seen crawling across a room.
static func _model_round(kit: MeshKit) -> void:
	var black: Material = Mats.bullet_black()
	var band: Material = Mats.brass()
	kit.tube(0.0, 0.012, 0.026, Vector3(0, 0, -0.072), black, true, 12)      # tip
	kit.tube(0.012, 0.021, 0.034, Vector3(0, 0, -0.042), black, true, 12)    # ogive
	kit.tube(0.021, 0.021, 0.050, Vector3(0, 0, 0.000), black, true, 12)     # bearing surface
	kit.tube(0.0215, 0.0215, 0.005, Vector3(0, 0, 0.004), band, true, 12)    # driving band
	kit.tube(0.021, 0.016, 0.018, Vector3(0, 0, 0.034), black, true, 12)     # boat tail


## A carrot: fat orange root, tapered to a point, with a tuft of green at the blunt end.
static func _model_carrot(kit: MeshKit) -> void:
	var orange: Material = Mats.carrot()
	var green: Material = Mats.carrot_top()
	kit.tube(0.0, 0.020, 0.075, Vector3(0, 0, -0.060), orange, true, 10)
	kit.tube(0.020, 0.032, 0.070, Vector3(0, 0, 0.012), orange, true, 10)
	kit.tube(0.032, 0.030, 0.012, Vector3(0, 0, 0.053), orange, true, 10)
	for i: int in 5:
		var lean: float = TAU * i / 5.0
		kit.box(Vector3(0.010, 0.044, 0.010), Vector3(sin(lean) * 0.016, cos(lean) * 0.016, 0.082), green,
			Vector3(0.35 * cos(lean), 0.35 * sin(lean), 0))


func set_style(next: StringName) -> void:
	if style == next:
		return
	style = next
	if next == &"carrot":
		if _carrot_mesh == null:
			_carrot_mesh = MeshKit.cached(&"carrot_round", _model_carrot)
		_round_instance.mesh = _carrot_mesh
		_trail.material_override = Mats.carrot_trail()
	else:
		_round_instance.mesh = _round_mesh
		_trail.material_override = null


func launch(from: Vector3, dir: Vector3, by: Node, size: float = 1.0, pierce: int = 0, speed: float = 1.0) -> void:
	active = true
	pierce_left = pierce
	_heavy = pierce > 0      # stays true after its last pierce is spent
	speed_scale = speed
	_passed.clear()
	_size = size
	_body.scale = Vector3.ONE * size
	visible = true
	age = 0.0
	_travelled = 0.0
	shooter = by
	direction = dir.normalized()
	global_position = from
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	look_at(from + direction, up)
	_update_trail()
	set_physics_process(true)


func deactivate() -> void:
	active = false
	visible = false
	shooter = null
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	step(TimeManager.world_delta(delta))


func step(wd: float) -> void:
	if not active or wd <= 0.0:
		return
	age += wd
	if age >= T.bullet_life:
		deactivate()
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + direction * T.bullet_speed * speed_scale * wd
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK)
	query.collide_with_areas = true
	query.hit_from_inside = false
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		var skip: Array[RID] = [(shooter as CollisionObject3D).get_rid()]
		# Whoever fired it must not hit the shield they are standing behind.
		if shooter.has_method(&"bullet_excludes"):
			skip.append_array(shooter.call(&"bullet_excludes"))
		skip.append_array(_passed)
		query.exclude = skip
	elif not _passed.is_empty():
		query.exclude = _passed
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
		_travelled += from.distance_to(to)
		_update_trail()
		return
	var collider: Object = result["collider"]
	var point: Vector3 = result["position"]
	var normal: Vector3 = result["normal"]
	global_position = point
	if _heavy and collider is Pickup:
		# A heavy round punches past a loose gun tumbling out of a dead hand.
		_passed.append(result["rid"])
		return
	var bounced: bool = false
	if collider.has_method(&"on_bullet_hit"):
		# A handler that returns true has turned the bullet away instead of stopping it.
		var answer: Variant = collider.call(&"on_bullet_hit", self, point, normal)
		bounced = answer is bool and answer
	else:
		Shatter.burst(Game.entities_root(self), point + normal * 0.05, 4, Mats.pink_bright(),
			Vector3.ONE * 0.02, normal * 1.5, 0.05)
	hit.emit(collider, point)
	if not bounced and pierce_left > 0 and collider is PinkDude:
		# Heavy rounds go straight through a dude and on to the next one.
		pierce_left -= 1
		_passed.append(result["rid"])
		return
	if not bounced:
		deactivate()
		return
	# Ricochet: it now belongs to nobody and can kill whoever fired it.
	direction = Gun.scatter(direction.bounce(normal).normalized(), deg_to_rad(9.0))
	shooter = null
	global_position = point + normal * 0.08
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	look_at(global_position + direction, up)
	_travelled = 0.0
	_update_trail()
	Sfx.play(&"ricochet", point)
	deflected.emit(collider)


func _update_trail() -> void:
	var length: float = clampf(_travelled, 0.01, TRAIL_LENGTH * _size)
	_trail.scale = Vector3(_size, length, _size)
	_trail.position = Vector3(0, 0, length * 0.5 + 0.04 * _size)
