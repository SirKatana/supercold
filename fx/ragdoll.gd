class_name Ragdoll
extends Node3D
## A Humanoid gone limp. It is a position-based (Verlet) simulation, not RigidBody3D: the 21
## joints are points, bones are distance constraints, and joint limits are minimum and maximum
## distances across each joint. Deterministic, testable headless, and it runs on whichever
## clock it is told to: real time for the player, world time for dudes.

const T: Tuning = preload("res://data/tuning.tres")
const POINT_RADIUS: float = 0.07
const ITERATIONS: int = 8
const GRAVITY: float = 9.8
const DAMPING: float = 0.992
const FRICTION: float = 0.55
const WORLD_MASK: int = 1 | 32

const BONES: Array = [
	[&"neck", &"head"], [&"chest", &"neck"],
	[&"shoulder_l", &"elbow_l"], [&"elbow_l", &"wrist_l"], [&"wrist_l", &"hand_l"],
	[&"shoulder_r", &"elbow_r"], [&"elbow_r", &"wrist_r"], [&"wrist_r", &"hand_r"],
	[&"hip_l", &"knee_l"], [&"knee_l", &"ankle_l"], [&"ankle_l", &"toe_l"],
	[&"hip_r", &"knee_r"], [&"knee_r", &"ankle_r"], [&"ankle_r", &"toe_r"],
]

## Rigid links that hold the torso together.
const BRACES: Array = [
	[&"chest", &"spine"], [&"spine", &"pelvis"],
	[&"chest", &"shoulder_l"], [&"chest", &"shoulder_r"], [&"shoulder_l", &"shoulder_r"],
	[&"neck", &"shoulder_l"], [&"neck", &"shoulder_r"], [&"spine", &"shoulder_l"], [&"spine", &"shoulder_r"],
	[&"pelvis", &"hip_l"], [&"pelvis", &"hip_r"], [&"hip_l", &"hip_r"],
	[&"spine", &"hip_l"], [&"spine", &"hip_r"],
]

## Joint limits as [a, b, min fraction, max fraction] of the standing distance between a and b.
const LIMITS: Array = [
	[&"hip_l", &"ankle_l", 0.62, 1.0], [&"hip_r", &"ankle_r", 0.62, 1.0],            # knees
	[&"shoulder_l", &"wrist_l", 0.50, 1.0], [&"shoulder_r", &"wrist_r", 0.50, 1.0],  # elbows
	[&"elbow_l", &"hand_l", 0.80, 1.0], [&"elbow_r", &"hand_r", 0.80, 1.0],          # wrists
	[&"knee_l", &"toe_l", 0.78, 1.02], [&"knee_r", &"toe_r", 0.78, 1.02],            # ankles
	[&"head", &"chest", 0.82, 1.0],                                                   # neck
	[&"chest", &"pelvis", 0.80, 1.0],                                                 # spine
	[&"knee_l", &"knee_r", 0.35, 3.2], [&"ankle_l", &"ankle_r", 0.30, 5.0],          # legs do not cross
	[&"head", &"pelvis", 0.45, 1.0],                                                  # no folding in half
	[&"elbow_l", &"spine", 0.45, 2.2], [&"elbow_r", &"spine", 0.45, 2.2],            # arms stay outside the ribs
	[&"chest", &"knee_l", 0.62, 1.05], [&"chest", &"knee_r", 0.62, 1.05],            # hips
	[&"wrist_l", &"pelvis", 0.5, 4.0], [&"wrist_r", &"pelvis", 0.5, 4.0],            # arms sprawl
]

signal shattered

## Simulated seconds per second of whichever clock drives it.
var speed: float = 0.75
## Dudes fall in slow motion with the rest of the world. The player's body does not.
var use_world_time: bool = false
## World or real seconds until the body bursts into shards. Negative: it stays.
var shatter_after: float = -1.0
var body_scale: float = 1.0
var material: Material

var names: Array[StringName] = Humanoid.JOINTS
var pos: PackedVector3Array = []
var prev: PackedVector3Array = []

var _links: Array = []
var _skin: Humanoid
## The ceiling this body is under, or a great height on a floor that is open to the sky. A
## flung body stops against it instead of sailing off through the roof, and whatever is hanging
## there hears about it (`hit_ceiling`).
var ceiling_y: float = 1.0e9
var _hit_the_ceiling: bool = false
var _ground: PackedFloat32Array = []
var _touching: PackedByteArray = []
## The wall each joint struck this step, as a plane (normal, distance). The solver clamps
## against it, or the second solve pass pushes joints back into the wall they just hit.
var _wall_normal: PackedVector3Array = []
var _wall_d: PackedFloat32Array = []
var _still_frames: int = 0
var _age: float = 0.0
var _last_dt: float = 0.0


## `joints` are world positions in Humanoid.JOINTS order: the pose the body was in when it died.
## Anything hanging from the ceiling that a flying body slams into.
func _rattle_the_ceiling(at: Vector3) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"hanging"):
		var thing: Node3D = node as Node3D
		if thing != null and thing.global_position.distance_to(at) <= 1.6 and thing.has_method(&"knock"):
			thing.call(&"knock", (at - thing.global_position).normalized() + Vector3.UP * 0.2)


static func spawn(parent: Node, joints: PackedVector3Array, scale_factor: float, impulse: Vector3,
		body_material: Material, sim_speed: float) -> Ragdoll:
	var r := Ragdoll.new()
	r.material = body_material
	r.speed = sim_speed
	r.body_scale = scale_factor
	# Head room: the ceiling of this floor, less a little for the point's own size.
	if Game.data != null and not Game.data.open_sky:
		r.ceiling_y = T.wall_height - POINT_RADIUS
	parent.add_child(r)
	r.add_to_group(&"ragdolls")
	r.setup(joints, impulse)
	return r


## Convenience: a body standing upright at `at`.
static func spawn_standing(parent: Node, at: Transform3D, impulse: Vector3, body_material: Material,
		sim_speed: float) -> Ragdoll:
	return spawn(parent, Humanoid.to_world(Humanoid.rest_local(), at, 1.0), 1.0, impulse, body_material, sim_speed)


func setup(joints: PackedVector3Array, impulse: Vector3) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	pos = joints.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var dt: float = 1.0 / 60.0
	var feet: float = minf(pos[Humanoid.index_of(&"ankle_l")].y, pos[Humanoid.index_of(&"ankle_r")].y)
	for i: int in pos.size():
		# The hit lands high, so the upper body leads and the feet trail. A little noise per
		# joint keeps the fall from looking like a statue tipping over.
		var height: float = clampf((pos[i].y - feet) / (1.7 * body_scale), 0.0, 1.0)
		var kick: Vector3 = impulse * (0.35 + 0.65 * height)
		kick += Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.6, 0.6))
		prev.append(pos[i] - kick * dt)

	for bone: Array in BONES:
		_add_link(bone[0], bone[1], 1.0, 1.0)
	for brace: Array in BRACES:
		_add_link(brace[0], brace[1], 1.0, 1.0)
	for limit: Array in LIMITS:
		_add_link(limit[0], limit[1], limit[2], limit[3])
	_skin = Humanoid.create(self, material, body_scale)
	_skin.apply(pos)


func _add_link(a: StringName, b: StringName, low: float, high: float) -> void:
	var rest: float = rest_length(a, b)
	_links.append([Humanoid.index_of(a), Humanoid.index_of(b), rest * low, rest * high])


func point(joint: StringName) -> Vector3:
	return pos[Humanoid.index_of(joint)]


func bone_length(from: StringName, to: StringName) -> float:
	return point(from).distance_to(point(to))


func rest_length(from: StringName, to: StringName) -> float:
	return Humanoid.REST[from].distance_to(Humanoid.REST[to]) * body_scale


## Average joint speed in metres per simulated second, for "has it settled" checks.
func motion() -> float:
	var total: float = 0.0
	for i: int in pos.size():
		total += pos[i].distance_to(prev[i])
	return total * 60.0 / pos.size()


func _physics_process(delta: float) -> void:
	var dt: float = (TimeManager.world_delta(delta) if use_world_time else delta) * speed
	if dt <= 0.0:
		return
	_age += dt / speed
	if shatter_after >= 0.0 and _age >= shatter_after:
		shatter()
		return
	if _still_frames > 45:
		return    # lying still: stop simulating, keep counting toward the shatter
	step(dt)
	_still_frames = _still_frames + 1 if motion() < 0.06 else 0


## Bursts the body into shards of its own colour at the big joints, and removes it.
func shatter() -> void:
	var world: Node = get_parent()
	for joint: StringName in [&"head", &"chest", &"pelvis", &"knee_l", &"knee_r", &"elbow_l", &"elbow_r"]:
		Shatter.burst(world, point(joint), 4, material, Vector3.ONE * 0.12 * body_scale, Vector3.UP * 0.5, 0.17 * body_scale)
	Sfx.play(&"shatter", point(&"chest"))
	shattered.emit()
	queue_free()


func step(dt: float) -> void:
	if dt <= 0.0:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var count: int = pos.size()
	# Verlet keeps velocity as (pos - prev), which assumes a constant step. World time does
	# not give one, so the carried velocity is rescaled by how this step compares to the last.
	var ratio: float = dt / _last_dt if _last_dt > 0.0 else 1.0
	_last_dt = dt
	for i: int in count:
		var velocity: Vector3 = (pos[i] - prev[i]) * DAMPING * ratio
		prev[i] = pos[i]
		pos[i] += velocity + Vector3.DOWN * GRAVITY * Game.gravity_scale * dt * dt

	# Where is the ground under each joint? One ray each, then the clamp is free to run
	# inside the solver loop, which is what keeps bones from stretching against the floor.
	_ground.resize(count)
	for i: int in count:
		var top: Vector3 = prev[i] + Vector3.UP * 0.25
		var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 3.0, WORLD_MASK)
		var hit: Dictionary = space.intersect_ray(query)
		_ground[i] = (hit["position"] as Vector3).y + POINT_RADIUS if not hit.is_empty() else -1000.0

	_touching.resize(count)
	_touching.fill(0)
	_wall_normal.resize(count)
	_wall_normal.fill(Vector3.ZERO)
	_wall_d.resize(count)
	_solve(ITERATIONS)
	for i: int in count:
		_hit_walls(space, i)
	_solve(3)

	for i: int in count:
		if _touching[i] == 1:
			# Scrape along the ground instead of sliding forever.
			var slide: Vector3 = pos[i] - prev[i]
			prev[i] = pos[i] - Vector3(slide.x * (1.0 - FRICTION), minf(slide.y, 0.0) * 0.2, slide.z * (1.0 - FRICTION))
	_skin.apply(pos)


func _solve(iterations: int) -> void:
	for iteration: int in iterations:
		for link: Array in _links:
			var a: int = link[0]
			var b: int = link[1]
			var between: Vector3 = pos[b] - pos[a]
			var d: float = between.length()
			if d < 0.0001:
				continue
			var target: float = clampf(d, link[2], link[3])
			if absf(target - d) < 0.00001:
				continue
			var correction: Vector3 = between * ((d - target) / d * 0.5)
			pos[a] += correction
			pos[b] -= correction
		for i: int in pos.size():
			if pos[i].y < _ground[i]:
				pos[i].y = _ground[i]
				_touching[i] = 1
			if pos[i].y > ceiling_y:
				pos[i].y = ceiling_y
				prev[i].y = ceiling_y + (ceiling_y - prev[i].y) * 0.25      # a little bounce off it
				if not _hit_the_ceiling:
					_hit_the_ceiling = true
					_rattle_the_ceiling(pos[i])
			if _wall_normal[i] != Vector3.ZERO:
				var depth: float = _wall_d[i] - pos[i].dot(_wall_normal[i])
				if depth > 0.0:
					pos[i] += _wall_normal[i] * depth


## Sweeps the joint from where it was to where it wants to be and stops it on walls.
## Floors are the ground clamp's job, so near-horizontal surfaces are ignored here.
func _hit_walls(space: PhysicsDirectSpaceState3D, i: int) -> void:
	var from: Vector3 = prev[i]
	var travel: Vector3 = pos[i] - from
	if travel.length() < 0.0005:
		return
	var query := PhysicsRayQueryParameters3D.create(from, pos[i] + travel.normalized() * POINT_RADIUS, WORLD_MASK)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	if absf(normal.y) > 0.7:
		return
	pos[i] = (hit["position"] as Vector3) + normal * POINT_RADIUS
	_wall_normal[i] = normal
	_wall_d[i] = pos[i].dot(normal)
	var v: Vector3 = pos[i] - prev[i]
	prev[i] = pos[i] - (v - normal * v.dot(normal)) * (1.0 - FRICTION)
