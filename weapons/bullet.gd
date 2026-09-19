class_name Bullet
extends Node3D
## Not a physics body. Each tick it advances on world time and sweeps a ray over
## the distance covered, so it cannot tunnel at any speed or time scale.

signal hit(collider: Object, point: Vector3)

const T: Tuning = preload("res://data/tuning.tres")
const MASK: int = 1 | 2 | 4 | 32 | 64  # world, player, enemies, breakables, flying items
const TRAIL_LENGTH: float = 1.8

var active: bool = false
var direction: Vector3 = Vector3.FORWARD
var shooter: Node = null
var age: float = 0.0

var _trail: MeshInstance3D
var _body: Node3D
var _travelled: float = 0.0
var _size: float = 1.0

static var _round_mesh: ArrayMesh
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
	var round_instance := MeshInstance3D.new()
	round_instance.mesh = _round_mesh
	round_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(round_instance)

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


func launch(from: Vector3, dir: Vector3, by: Node, size: float = 1.0) -> void:
	active = true
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
	var to: Vector3 = from + direction * T.bullet_speed * wd
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK)
	query.collide_with_areas = true
	query.hit_from_inside = false
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
		_travelled += from.distance_to(to)
		_update_trail()
		return
	var collider: Object = result["collider"]
	var point: Vector3 = result["position"]
	global_position = point
	if collider.has_method(&"on_bullet_hit"):
		collider.call(&"on_bullet_hit", self, point, result["normal"])
	else:
		var normal: Vector3 = result["normal"]
		Shatter.burst(Game.entities_root(self), point + normal * 0.05, 4, Mats.pink_bright(),
			Vector3.ONE * 0.02, normal * 1.5, 0.05)
	hit.emit(collider, point)
	deactivate()


func _update_trail() -> void:
	var length: float = clampf(_travelled, 0.01, TRAIL_LENGTH * _size)
	_trail.scale = Vector3(_size, length, _size)
	_trail.position = Vector3(0, 0, length * 0.5 + 0.04 * _size)
