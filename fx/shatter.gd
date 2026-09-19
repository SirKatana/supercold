class_name Shatter
extends Node3D
## A burst of shards in one MultiMesh. Motion is scripted and runs on world time.

const T: Tuning = preload("res://data/tuning.tres")
const FLOOR_Y: float = 0.04

var _multimesh: MultiMesh
var _pos: PackedVector3Array = []
var _vel: PackedVector3Array = []
var _spin: PackedVector3Array = []
var _rot: PackedVector3Array = []
var _scale: PackedVector3Array = []
var _age: float = 0.0
var _life: float = 3.0

static var _meshes: Dictionary[Material, PrismMesh] = {}


## `half_extents` is the volume shards start in, `impulse` pushes them all one way.
static func burst(parent: Node, origin: Vector3, count: int, material: Material, half_extents: Vector3,
		impulse: Vector3, shard_size: float = 0.16) -> Shatter:
	var s := Shatter.new()
	parent.add_child(s)
	s.global_position = origin
	s._life = T.shard_life
	if not _meshes.has(material):
		var shared := PrismMesh.new()
		shared.size = Vector3.ONE
		shared.material = material
		_meshes[material] = shared
	var mesh: PrismMesh = _meshes[material]
	s._multimesh = MultiMesh.new()
	s._multimesh.transform_format = MultiMesh.TRANSFORM_3D
	s._multimesh.mesh = mesh
	s._multimesh.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = s._multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(instance)
	for i: int in count:
		var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * half_extents
		s._pos.append(offset)
		s._vel.append(offset.normalized() * randf_range(1.0, 3.5) + impulse * randf_range(0.5, 1.0)
			+ Vector3.UP * randf_range(0.5, 2.5))
		s._spin.append(Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))
		s._rot.append(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		s._scale.append(Vector3(randf_range(0.5, 1.4), randf_range(0.5, 1.4), randf_range(0.3, 0.9)) * shard_size)
	s._write()
	return s


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	if wd <= 0.0:
		return
	_age += wd
	if _age >= _life:
		queue_free()
		return
	var floor_local: float = FLOOR_Y - global_position.y
	for i: int in _pos.size():
		if _pos[i].y <= floor_local and _vel[i].y <= 0.0:
			_pos[i].y = floor_local
			_vel[i] = _vel[i].lerp(Vector3.ZERO, minf(1.0, wd * 8.0))
			_vel[i].y = 0.0
			_spin[i] = _spin[i].lerp(Vector3.ZERO, minf(1.0, wd * 8.0))
		else:
			_vel[i].y -= T.throw_gravity * wd
		_pos[i] += _vel[i] * wd
		_rot[i] += _spin[i] * wd
	_write()


func _write() -> void:
	var fade: float = clampf((_life - _age) / 0.6, 0.0, 1.0)
	for i: int in _pos.size():
		var b := Basis.from_euler(_rot[i]).scaled(_scale[i] * fade)
		_multimesh.set_instance_transform(i, Transform3D(b, _pos[i]))
