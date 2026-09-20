class_name Pickup
extends Area3D
## Anything that can be held and thrown. Flight is a scripted ballistic step on
## world time with a raycast sweep, so nothing tunnels and nothing uses RigidBody3D.

signal landed
signal thrown_hit(target: Object)

enum State { RESTING, HELD, FLYING }

const T: Tuning = preload("res://data/tuning.tres")
const LAYER_PICKUP: int = 8
const LAYER_FLYING: int = 64
const HIT_MASK: int = 1 | 4 | 32  # world, enemies, breakables
const REST_HEIGHT: float = 0.08

var kind: StringName = &"item"
var state: State = State.RESTING
var fragile: bool = false
var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var thrower: Node = null
## True only for a deliberate throw. A weapon popped out of a hand does no damage.
var dangerous: bool = false
## Damage dealt to a dude when thrown. The ram overrides this.
var blunt_damage: int = 1
## Where the item sits relative to the fist when held.
var hold_offset: Vector3 = Vector3.ZERO
## Heavy things do not fly as fast.
var throw_speed_scale: float = 1.0
## Brought up in the lift from the floor below. Security wants it.
var contraband: bool = false

var _mesh_root: Node3D


func _ready() -> void:
	add_to_group(&"pickups")
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape3D.new()
	shape.shape = _make_shape()
	shape.position = _shape_offset()
	add_child(shape)
	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	_build_mesh(_mesh_root)
	if state == State.HELD:
		_mesh_root.rotation = Vector3.ZERO
	_apply_layer()


## The volume hands and bullets find. Big items override it.
func _make_shape() -> Shape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	return sphere


func _shape_offset() -> Vector3:
	return Vector3.ZERO


## Overridden by subclasses to add MeshInstance3D children.
func _build_mesh(_root: Node3D) -> void:
	pass


func add_box(root: Node3D, size: Vector3, at: Vector3, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material if material != null else Mats.black()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## Would a security guard take this off you?
func is_weapon() -> bool:
	return false


## What has to survive a lift ride: enough to rebuild this exact item on the next floor.
func carry_state() -> Dictionary:
	return {"kind": kind}


func apply_carry_state(_state: Dictionary) -> void:
	pass


func is_available() -> bool:
	return state != State.HELD and not is_queued_for_deletion()


func _apply_layer() -> void:
	match state:
		State.RESTING:
			collision_layer = LAYER_PICKUP
		State.FLYING:
			collision_layer = LAYER_PICKUP | LAYER_FLYING
		State.HELD:
			collision_layer = 0


func attach_to(holder: Node3D) -> void:
	state = State.HELD
	velocity = Vector3.ZERO
	dangerous = false
	thrower = null
	if get_parent() != null:
		reparent(holder, false)
	else:
		holder.add_child(self)
	transform = Transform3D(Basis.IDENTITY, hold_offset)
	# Flight leaves the mesh tumbled. In a hand it must sit straight.
	if _mesh_root != null:
		_mesh_root.rotation = Vector3.ZERO
	_apply_layer()


func _release_to_world(at: Vector3, facing: Basis) -> void:
	var world: Node = Game.entities_root(self)
	if get_parent() != world:
		reparent(world, false)
	global_transform = Transform3D(facing.orthonormalized(), at)


func throw_from(at: Vector3, initial_velocity: Vector3, by: Node) -> void:
	_release_to_world(at, global_transform.basis)
	state = State.FLYING
	velocity = initial_velocity
	thrower = by
	dangerous = true
	spin = Vector3(randf_range(-6, 6), randf_range(8, 14), randf_range(-6, 6))
	_apply_layer()


## Knocked out of a hand: floats up so the player can catch it.
func pop_up(at: Vector3, toward: Vector3) -> void:
	_release_to_world(at, global_transform.basis)
	state = State.FLYING
	var flat: Vector3 = (toward - at) * Vector3(1, 0, 1)
	velocity = flat.normalized() * 1.2 + Vector3.UP * 4.2
	thrower = null
	dangerous = false
	spin = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	_apply_layer()


func drop(at: Vector3) -> void:
	_release_to_world(at, global_transform.basis)
	state = State.FLYING
	velocity = Vector3.ZERO
	thrower = null
	dangerous = false
	spin = Vector3(2, 0, 3)
	_apply_layer()


func _physics_process(delta: float) -> void:
	if state == State.FLYING:
		step_flight(TimeManager.world_delta(delta))


func step_flight(wd: float) -> void:
	if wd <= 0.0:
		return
	velocity.y -= T.throw_gravity * wd
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * wd
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.collide_with_areas = false
	if is_instance_valid(thrower) and thrower is CollisionObject3D:
		query.exclude = [(thrower as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_mesh_root.rotation += spin * wd
		return
	_on_flight_hit(hit["collider"], hit["position"], hit["normal"])


func _on_flight_hit(collider: Object, point: Vector3, normal: Vector3) -> void:
	if normal.length() < 0.5:
		normal = Vector3.UP      # started inside something: no normal to bounce off
	global_position = point + normal * REST_HEIGHT
	if dangerous and collider.has_method(&"on_thrown_hit"):
		collider.call(&"on_thrown_hit", self)
		thrown_hit.emit(collider)
	if fragile and dangerous:
		shatter()
		return
	dangerous = false
	if normal.y > 0.7 and velocity.length() < 5.0:
		_come_to_rest()
	else:
		velocity = velocity.bounce(normal) * 0.28
		if normal.y > 0.7 and velocity.length() < 1.2:
			_come_to_rest()


func _come_to_rest() -> void:
	state = State.RESTING
	velocity = Vector3.ZERO
	thrower = null
	_mesh_root.rotation = Vector3(0, _mesh_root.rotation.y, 0)
	_apply_layer()
	landed.emit()


func shatter() -> void:
	Shatter.burst(Game.entities_root(self), global_position, 8, Mats.black(), Vector3.ONE * 0.08,
		velocity * 0.15, 0.07)
	Sfx.play(&"shatter", global_position)
	queue_free()


## A flying item stops a bullet. Fragile ones break.
func on_bullet_hit(_bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	if fragile:
		shatter()
	else:
		velocity = velocity * 0.3
