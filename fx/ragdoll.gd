class_name Ragdoll
extends Node3D
## A full humanoid that goes limp: head, neck, spine, shoulders, elbows, wrists, hips,
## knees and ankles. It is a position-based (Verlet) simulation, not RigidBody3D: joints
## are points, bones are distance constraints, and joint limits are minimum and maximum
## distances between the points either side of a joint. That keeps it deterministic,
## testable headless, and free to run on whatever clock we hand it.

const POINT_RADIUS: float = 0.07
const ITERATIONS: int = 8
const GRAVITY: float = 9.8
const DAMPING: float = 0.992
const FRICTION: float = 0.55
const WORLD_MASK: int = 1 | 32

## Joint name -> standing position in metres, for a 1.8 m human facing -Z.
const REST: Dictionary[StringName, Vector3] = {
	&"head": Vector3(0, 1.70, 0), &"neck": Vector3(0, 1.53, 0), &"chest": Vector3(0, 1.36, 0),
	&"spine": Vector3(0, 1.15, 0), &"pelvis": Vector3(0, 0.96, 0),
	&"shoulder_l": Vector3(-0.20, 1.46, 0), &"shoulder_r": Vector3(0.20, 1.46, 0),
	&"elbow_l": Vector3(-0.25, 1.17, 0.02), &"elbow_r": Vector3(0.25, 1.17, 0.02),
	&"wrist_l": Vector3(-0.27, 0.91, -0.03), &"wrist_r": Vector3(0.27, 0.91, -0.03),
	&"hand_l": Vector3(-0.27, 0.78, -0.05), &"hand_r": Vector3(0.27, 0.78, -0.05),
	&"hip_l": Vector3(-0.10, 0.93, 0), &"hip_r": Vector3(0.10, 0.93, 0),
	&"knee_l": Vector3(-0.11, 0.50, -0.02), &"knee_r": Vector3(0.11, 0.50, -0.02),
	&"ankle_l": Vector3(-0.11, 0.08, 0.02), &"ankle_r": Vector3(0.11, 0.08, 0.02),
	&"toe_l": Vector3(-0.11, 0.05, -0.20), &"toe_r": Vector3(0.11, 0.05, -0.20),
}

## Visible bones: [from, to, thickness]. The joint between two bones is the point they share.
const BONES: Array = [
	[&"neck", &"head", 0.10], [&"chest", &"neck", 0.11],
	[&"shoulder_l", &"elbow_l", 0.095], [&"elbow_l", &"wrist_l", 0.08], [&"wrist_l", &"hand_l", 0.085],
	[&"shoulder_r", &"elbow_r", 0.095], [&"elbow_r", &"wrist_r", 0.08], [&"wrist_r", &"hand_r", 0.085],
	[&"hip_l", &"knee_l", 0.135], [&"knee_l", &"ankle_l", 0.105], [&"ankle_l", &"toe_l", 0.09],
	[&"hip_r", &"knee_r", 0.135], [&"knee_r", &"ankle_r", 0.105], [&"ankle_r", &"toe_r", 0.09],
]

## Rigid links that hold the torso together but are not drawn as limbs.
const BRACES: Array = [
	[&"chest", &"spine"], [&"spine", &"pelvis"],
	[&"chest", &"shoulder_l"], [&"chest", &"shoulder_r"], [&"shoulder_l", &"shoulder_r"],
	[&"neck", &"shoulder_l"], [&"neck", &"shoulder_r"], [&"spine", &"shoulder_l"], [&"spine", &"shoulder_r"],
	[&"pelvis", &"hip_l"], [&"pelvis", &"hip_r"], [&"hip_l", &"hip_r"],
	[&"spine", &"hip_l"], [&"spine", &"hip_r"],
]

## Joint limits as [a, b, min fraction, max fraction] of the rest distance between a and b.
## A knee cannot fold flat or bend backwards past straight, a neck cannot fold onto the chest,
## and the spine bends but does not jack-knife.
const LIMITS: Array = [
	[&"hip_l", &"ankle_l", 0.62, 1.0], [&"hip_r", &"ankle_r", 0.62, 1.0],            # knees
	[&"shoulder_l", &"wrist_l", 0.50, 1.0], [&"shoulder_r", &"wrist_r", 0.50, 1.0],  # elbows
	[&"elbow_l", &"hand_l", 0.80, 1.0], [&"elbow_r", &"hand_r", 0.80, 1.0],          # wrists
	[&"knee_l", &"toe_l", 0.78, 1.02], [&"knee_r", &"toe_r", 0.78, 1.02],            # ankles
	[&"head", &"chest", 0.82, 1.0],                                                   # neck
	[&"chest", &"pelvis", 0.80, 1.0],                                                 # spine
	[&"knee_l", &"knee_r", 0.35, 3.2], [&"ankle_l", &"ankle_r", 0.30, 5.0],          # legs do not pass through each other
	[&"head", &"pelvis", 0.45, 1.0],                                                  # no folding in half
	[&"elbow_l", &"spine", 0.45, 2.2], [&"elbow_r", &"spine", 0.45, 2.2],            # arms stay outside the ribs
	[&"chest", &"knee_l", 0.62, 1.05], [&"chest", &"knee_r", 0.62, 1.05],            # hips: the torso cannot fold onto the thighs
	[&"wrist_l", &"pelvis", 0.5, 4.0], [&"wrist_r", &"pelvis", 0.5, 4.0],            # arms sprawl instead of tucking under
]

## Seconds of simulated time per real second. Set by whoever spawns it.
var speed: float = 0.75
var material: Material

var names: Array[StringName] = []
var pos: PackedVector3Array = []
var prev: PackedVector3Array = []

var _index: Dictionary[StringName, int] = {}
var _links: Array = []          # [ia, ib, min, max]
var _bone_nodes: Array[MeshInstance3D] = []
var _torso_upper: MeshInstance3D
var _torso_lower: MeshInstance3D
var _head: MeshInstance3D
var _ground: PackedFloat32Array = []
var _touching: PackedByteArray = []
var _still_frames: int = 0


## Builds a limp body standing at `at`, then throws it with `impulse` (metres per second).
static func spawn(parent: Node, at: Transform3D, impulse: Vector3, body_material: Material, sim_speed: float) -> Ragdoll:
	var r := Ragdoll.new()
	r.material = body_material
	r.speed = sim_speed
	parent.add_child(r)
	r.add_to_group(&"ragdolls")
	r.setup(at, impulse)
	return r


func setup(at: Transform3D, impulse: Vector3) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for joint: StringName in REST:
		_index[joint] = names.size()
		names.append(joint)
		pos.append(at * REST[joint])
	var dt: float = 1.0 / 60.0
	for i: int in names.size():
		# The hit lands high, so the upper body leads and the feet trail. A little noise
		# per joint keeps the fall from looking like a statue tipping over.
		var height: float = clampf(REST[names[i]].y / 1.7, 0.0, 1.0)
		var kick: Vector3 = impulse * (0.35 + 0.65 * height)
		kick += Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.6, 0.6))
		prev.append(pos[i] - kick * dt)

	for bone: Array in BONES:
		_add_link(bone[0], bone[1], 1.0, 1.0)
	for brace: Array in BRACES:
		_add_link(brace[0], brace[1], 1.0, 1.0)
	for limit: Array in LIMITS:
		_add_link(limit[0], limit[1], limit[2], limit[3])
	_build_meshes()
	_pose_meshes()


func _add_link(a: StringName, b: StringName, low: float, high: float) -> void:
	var rest: float = REST[a].distance_to(REST[b])
	_links.append([_index[a], _index[b], rest * low, rest * high])


func point(joint: StringName) -> Vector3:
	return pos[_index[joint]]


func bone_length(from: StringName, to: StringName) -> float:
	return point(from).distance_to(point(to))


func rest_length(from: StringName, to: StringName) -> float:
	return REST[from].distance_to(REST[to])


## Total speed of all joints, for "has it settled" checks.
func motion() -> float:
	var total: float = 0.0
	for i: int in pos.size():
		total += pos[i].distance_to(prev[i])
	return total * 60.0 / pos.size()


func _physics_process(delta: float) -> void:
	step(delta * speed)
	# Once it lies still, stop simulating. It stays where it fell.
	_still_frames = _still_frames + 1 if motion() < 0.06 else 0
	if _still_frames > 45:
		set_physics_process(false)


func step(dt: float) -> void:
	if dt <= 0.0:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var count: int = pos.size()
	for i: int in count:
		var velocity: Vector3 = (pos[i] - prev[i]) * DAMPING
		prev[i] = pos[i]
		pos[i] += velocity + Vector3.DOWN * GRAVITY * dt * dt

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
	_solve(ITERATIONS)
	for i: int in count:
		_hit_walls(space, i)
	_solve(3)

	for i: int in count:
		if _touching[i] == 1:
			# Scrape along the ground instead of sliding forever.
			var slide: Vector3 = pos[i] - prev[i]
			prev[i] = pos[i] - Vector3(slide.x * (1.0 - FRICTION), minf(slide.y, 0.0) * 0.2, slide.z * (1.0 - FRICTION))
	_pose_meshes()


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


## Sweeps the joint sideways from where it was to where it wants to be and stops it on walls.
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
	var v: Vector3 = pos[i] - prev[i]
	prev[i] = pos[i] - (v - normal * v.dot(normal)) * (1.0 - FRICTION)


# ---------------------------------------------------------------- looks

func _box(size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build_meshes() -> void:
	for bone: Array in BONES:
		var thickness: float = bone[2]
		_bone_nodes.append(_box(Vector3(thickness, thickness, 1.0)))
	_torso_upper = _box(Vector3(0.40, 0.22, 1.0))
	_torso_lower = _box(Vector3(0.32, 0.20, 1.0))
	_head = MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = 0.12
	skull.height = 0.27
	skull.radial_segments = 10
	skull.rings = 6
	skull.material = material
	_head.mesh = skull
	add_child(_head)


func _pose_meshes() -> void:
	for i: int in BONES.size():
		_stretch(_bone_nodes[i], point(BONES[i][0]), point(BONES[i][1]), Vector3.UP)
	var across: Vector3 = point(&"shoulder_r") - point(&"shoulder_l")
	_stretch(_torso_upper, point(&"spine"), point(&"neck"), across)
	_stretch(_torso_lower, point(&"pelvis") + (point(&"pelvis") - point(&"spine")) * 0.35, point(&"spine"),
		point(&"hip_r") - point(&"hip_l"))
	_head.global_position = point(&"head") + (point(&"head") - point(&"neck")).normalized() * 0.03


## Lays a unit-length box from `a` to `b`. `side` fixes the roll, which matters for the torso.
func _stretch(node: MeshInstance3D, a: Vector3, b: Vector3, side: Vector3) -> void:
	var along: Vector3 = b - a
	var length: float = along.length()
	if length < 0.001:
		return
	var z: Vector3 = along / length
	var x: Vector3 = side - z * side.dot(z)
	if x.length() < 0.001:
		x = z.cross(Vector3.RIGHT if absf(z.x) < 0.9 else Vector3.FORWARD)
	x = x.normalized()
	var y: Vector3 = z.cross(x).normalized()
	node.global_transform = Transform3D(Basis(x, y, z * length), (a + b) * 0.5)
