class_name Melt
extends Node3D
## A dude under the super gun. No ragdoll: he stays where he stood and runs like wax. The
## body sags straight down, glows hot, spreads, and is gone into a puddle that stays.

const T: Tuning = preload("res://data/tuning.tres")

var _skin: Humanoid
var _start: PackedVector3Array
var _feet: Vector3
var _age: float = 0.0
var _scale: float = 1.0
var _puddle: MeshInstance3D
var _puddle_age: float = 0.0


static func begin(parent: Node, joints: PackedVector3Array, body_scale: float, bulk: float) -> Melt:
	var m := Melt.new()
	parent.add_child(m)
	m.add_to_group(&"melts")
	m._start = joints.duplicate()
	m._scale = body_scale
	var ankle_l: Vector3 = joints[Humanoid.index_of(&"ankle_l")]
	var ankle_r: Vector3 = joints[Humanoid.index_of(&"ankle_r")]
	m._feet = (ankle_l + ankle_r) * 0.5
	m._feet.y = minf(ankle_l.y, ankle_r.y) - 0.08 * body_scale
	m._skin = Humanoid.create(m, Mats.melt_pink(), body_scale)
	m._skin.bulk = bulk
	m._skin.apply(joints)

	m._puddle = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 22
	disc.material = Mats.melt_pink()
	m._puddle.mesh = disc
	m._puddle.top_level = true
	m.add_child(m._puddle)
	m._puddle.global_position = Vector3(m._feet.x, m._feet.y + 0.015, m._feet.z)
	m._puddle.scale = Vector3(0.05, 1, 0.05)
	Sfx.play(&"melt", m._feet)
	return m


func progress() -> float:
	return clampf(_age / T.melt_seconds, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	if wd <= 0.0:
		return
	if _skin != null:
		_age += wd
		var t: float = progress()
		# Top of the body goes first and fastest, like a candle.
		var now := PackedVector3Array()
		now.resize(_start.size())
		for i: int in _start.size():
			var height: float = maxf(0.0, _start[i].y - _feet.y)
			var sag: float = clampf(t * (1.0 + height / (1.8 * _scale)), 0.0, 1.0)
			sag = sag * sag * (3.0 - 2.0 * sag)
			var flat := Vector3(_start[i].x - _feet.x, 0, _start[i].z - _feet.z)
			now[i] = Vector3(_feet.x, _feet.y, _feet.z) + flat * (1.0 + sag * 0.9) + Vector3.UP * (height * (1.0 - sag) + 0.03)
		_skin.bulk = lerpf(1.0, 1.7, t)
		_skin.apply(now)
		_puddle.scale = Vector3(1, 1, 1) * Vector3(lerpf(0.05, 0.95 * _scale, t), 1, lerpf(0.05, 0.95 * _scale, t))
		if t >= 1.0:
			_skin.queue_free()
			_skin = null
		return
	# Just the puddle now. It cools, then dries up.
	_puddle_age += wd
	if _puddle_age > 14.0:
		queue_free()
	elif _puddle_age > 11.0:
		_puddle.scale *= Vector3(0.985, 1, 0.985)
