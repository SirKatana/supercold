class_name FartCloud
extends Area3D
## A green stink drifting round the floor. Small, it makes a dude who walks through it gag.
## Shoot it (or punch, stab or hit it with anything) and it bursts to fill a room: every dude
## who stays in it chokes, and after a couple of seconds drops. Gas masks are immune. The
## player just gets a green screen and a cough.

signal burst_open

const T: Tuning = preload("res://data/tuning.tres")

var big: bool = false
var radius: float = 1.5

var _blobs: Array[MeshInstance3D] = []
var _offsets: PackedVector3Array = []
var _shape: SphereShape3D
var _goal: Vector3
var _age: float = 0.0
var _big_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _cough_clock: float = 0.0


func _ready() -> void:
	add_to_group(&"fart_clouds")
	collision_layer = 32          # breakables: bullets, punches, knives and thrown things reach it
	collision_mask = 4 | 2
	_rng.randomize()
	radius = T.fart_small_radius
	var shape := CollisionShape3D.new()
	_shape = SphereShape3D.new()
	_shape.radius = radius
	shape.shape = _shape
	add_child(shape)
	for i: int in 9:
		var mi := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 10
		ball.rings = 5
		mi.mesh = ball
		mi.material_override = Mats.fart()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_blobs.append(mi)
		_offsets.append(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.6), _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.2, 0.75))
	_goal = global_position
	_layout()


func _layout() -> void:
	for i: int in _blobs.size():
		var wobble := Vector3(sin(_age * 1.3 + i), sin(_age * 0.9 + i * 2.0) * 0.5, cos(_age * 1.1 + i * 1.7)) * 0.12
		_blobs[i].position = (_offsets[i] + wobble) * radius
		_blobs[i].scale = Vector3.ONE * radius * (0.55 + 0.12 * sin(_age * 1.7 + i))


func on_bullet_hit(_bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	burst()


func on_punched(_by: Node, _at: Vector3) -> void:
	burst()


func on_thrown_hit(_item: Pickup) -> void:
	burst()


## From a drifting puff to a room full of it.
func burst() -> void:
	if big:
		return
	big = true
	_big_left = T.fart_big_seconds
	Sfx.play(&"fart", global_position)
	Game.emit_noise(global_position, T.dude_hearing)
	burst_open.emit()


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	_age += wd
	if big:
		radius = move_toward(radius, T.fart_big_radius, wd * 9.0)
		_big_left -= wd
		if _big_left <= 0.0:
			queue_free()
			return
		if _big_left < 1.5:
			for blob: MeshInstance3D in _blobs:
				blob.transparency = 1.0 - _big_left / 1.5
	else:
		_drift(wd)
	_shape.radius = radius
	global_position.y = 1.1 + sin(_age * 0.8) * 0.15
	_layout()

	_cough_clock -= wd
	for body: Node3D in get_overlapping_bodies():
		if body is PinkDude:
			var dude: PinkDude = body
			# A small puff only makes him gag as he passes. The big one can kill.
			dude.breathe_gas(wd if big else wd * 0.35)
			if _cough_clock <= 0.0 and dude.choking:
				_cough_clock = 0.5
				Sfx.play(&"cough", dude.global_position)
		elif body is Player and big:
			(body as Player).in_stink = 0.3


## Wanders between random spots on the navmesh, slowly, on world time.
func _drift(wd: float) -> void:
	var flat := Vector3(_goal.x - global_position.x, 0, _goal.z - global_position.z)
	if flat.length() < 0.6:
		var map: RID = get_world_3d().navigation_map
		if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
			var wish: Vector3 = global_position + Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-9, 9))
			_goal = NavigationServer3D.map_get_closest_point(map, wish)
		return
	global_position += flat.normalized() * T.fart_drift_speed * wd
