class_name Debris
extends Node3D
## One loose chunk: scripted ballistic motion on world time, tumbles, comes to rest, fades.

const T: Tuning = preload("res://data/tuning.tres")

var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var life: float = 8.0
var rest_height: float = 0.09

var _age: float = 0.0
var _resting: bool = false


## A loose object with a ready-made mesh, like a pair of sunglasses.
static func spawn_mesh(parent: Node, at: Transform3D, initial_velocity: Vector3, mesh: Mesh) -> Debris:
	var d: Debris = spawn(parent, at, initial_velocity)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(mi)
	return d


static func spawn(parent: Node, at: Transform3D, initial_velocity: Vector3) -> Debris:
	var d := Debris.new()
	parent.add_child(d)
	d.add_to_group(&"debris")
	d.global_transform = at
	d.velocity = initial_velocity
	d.spin = Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-5, 5))
	return d


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	_age += wd
	if _age >= life:
		queue_free()
		return
	if _age > life - 1.0:
		scale = Vector3.ONE * maxf(0.01, life - _age)
	if _resting or wd <= 0.0:
		return
	velocity.y -= T.throw_gravity * wd
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * wd
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if hit.is_empty():
		global_position = to
		rotation += spin * wd
		return
	var normal: Vector3 = hit["normal"]
	if normal.length() < 0.5:
		# A ray that starts inside something reports no normal. Treat it as the floor and stop.
		normal = Vector3.UP
		velocity = Vector3.ZERO
	global_position = (hit["position"] as Vector3) + normal * rest_height
	velocity = velocity.bounce(normal) * 0.3
	spin *= 0.5
	if normal.y > 0.7 and velocity.length() < 1.5:
		_resting = true
		rotation.x = 0.0
