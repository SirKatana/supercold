class_name FartCloud
extends Area3D
## A bank of green fog drifting round the floor. It is drawn as dozens of soft overlapping
## puffs that always face the camera, denser near the floor, so it reads as fog and not a shape. Small, it makes a dude who walks through it gag.
## Shoot it (or punch, stab or hit it with anything) and it bursts to fill a room: every dude
## who stays in it chokes, and after a couple of seconds drops. Gas masks are immune. The
## player just gets a green screen and a cough.

signal burst_open

const T: Tuning = preload("res://data/tuning.tres")

var big: bool = false
var radius: float = 1.5

var _blobs: Array[MeshInstance3D] = []
var _offsets: PackedVector3Array = []
var _sizes: PackedFloat32Array = []

const PUFFS: int = 72
const SMALL_PUFFS: int = 16
var _shape: SphereShape3D
var _goal: Vector3
var _age: float = 0.0
var _big_left: float = 0.0
var _rng := RandomNumberGenerator.new()


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
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = Mats.fart()
	for i: int in PUFFS:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = i < SMALL_PUFFS
		add_child(mi)
		_blobs.append(mi)
		# Spread across a disc, and low: fog lies on the floor and thins toward head height.
		var angle: float = _rng.randf() * TAU
		var reach: float = sqrt(_rng.randf())
		var height: float = pow(_rng.randf(), 1.8)
		_offsets.append(Vector3(cos(angle) * reach, height, sin(angle) * reach))
		_sizes.append(_rng.randf_range(0.75, 1.35))
	_goal = global_position
	_layout()


func _layout() -> void:
	# The node floats at chest height. Puffs hang from just above it down to the floor.
	var floor_y: float = -global_position.y + 0.25
	var top_y: float = 1.3 if big else 0.7
	var count: int = PUFFS if big else SMALL_PUFFS
	for i: int in _blobs.size():
		var puff: MeshInstance3D = _blobs[i]
		puff.visible = i < count
		if not puff.visible:
			continue
		var o: Vector3 = _offsets[i]
		var drift := Vector3(sin(_age * 0.31 + i * 1.7), sin(_age * 0.23 + i) * 0.4, cos(_age * 0.27 + i * 2.3)) * 0.35
		puff.position = Vector3(o.x * radius, lerpf(floor_y, top_y, o.y), o.z * radius) + drift
		# Big soft puffs that breathe slowly. Lower ones are wider, like fog pooling.
		var size: float = _sizes[i] * (1.9 if big else 1.25) * (1.25 - o.y * 0.45) * (1.0 + 0.10 * sin(_age * 0.6 + i))
		puff.scale = Vector3(size, size, 1.0) * clampf(radius, 1.0, 2.6)
		# Seventy puffs on top of each other go solid. The burst cloud is drawn much thinner per
		# puff so you can still see the dudes choking inside it, thinnest at head height.
		puff.transparency = clampf((0.88 + o.y * 0.08) if big else 0.0, 0.0, 1.0) if _big_left >= 1.5 or not big else maxf(puff.transparency, 1.0 - _big_left / 1.5)


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
	else:
		_drift(wd)
	_shape.radius = radius
	global_position.y = 1.1 + sin(_age * 0.8) * 0.15
	_layout()

	for body: Node3D in get_overlapping_bodies():
		if body is PinkDude:
			var dude: PinkDude = body
			# A small puff only makes him gag as he passes. The big one can kill.
			dude.breathe_gas(wd if big else wd * 0.35)
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
