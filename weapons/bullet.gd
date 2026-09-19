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
var _travelled: float = 0.0

static var _core_mesh: BoxMesh
static var _trail_mesh: BoxMesh


func _ready() -> void:
	# One mesh shared by every bullet, so spawning one costs a node and nothing else.
	if _core_mesh == null:
		_core_mesh = BoxMesh.new()
		_core_mesh.size = Vector3(0.07, 0.07, 0.26)
		_core_mesh.material = Mats.pink_bright()
		_trail_mesh = BoxMesh.new()
		_trail_mesh.size = Vector3(0.04, 0.04, 1.0)
		_trail_mesh.material = Mats.pink_trail()
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	deactivate()


func launch(from: Vector3, dir: Vector3, by: Node) -> void:
	active = true
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
	var length: float = clampf(_travelled, 0.01, TRAIL_LENGTH)
	_trail.scale = Vector3(1, 1, length)
	_trail.position = Vector3(0, 0, length * 0.5 + 0.1)
