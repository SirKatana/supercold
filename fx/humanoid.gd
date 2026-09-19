class_name Humanoid
extends Node3D
## One human body, drawn from 21 joint positions. Alive, the joints come from `pose()`,
## a small forward-kinematics walk, aim and stagger. Dead, they come from the Ragdoll
## solver. Same skin either way, so a dude goes limp without changing shape.
##
## Parts are tapered cylinders and balls at every joint, mannequin style: neck, shoulders,
## elbows, wrists, hips, knees and ankles all show as joints.

const JOINTS: Array[StringName] = [
	&"head", &"neck", &"chest", &"spine", &"pelvis",
	&"shoulder_l", &"shoulder_r", &"elbow_l", &"elbow_r", &"wrist_l", &"wrist_r", &"hand_l", &"hand_r",
	&"hip_l", &"hip_r", &"knee_l", &"knee_r", &"ankle_l", &"ankle_r", &"toe_l", &"toe_r",
]

## Standing position of every joint in metres, for a 1.8 m human facing -Z.
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

## [part, from joint, to joint, kind, radius at from, radius at to, depth ratio, group]
## kind: limb (tapered tube), torso (tube flattened front to back), slab (box), and a
## trailing list of balls drawn at joints.
const PARTS: Array = [
	[&"neck", &"neck", &"head", &"limb", 0.052, 0.046, 1.0, &"head"],
	[&"chest", &"spine", &"neck", &"torso", 0.150, 0.190, 0.58, &"torso"],
	[&"belly", &"pelvis", &"spine", &"torso", 0.150, 0.150, 0.62, &"torso"],
	[&"upper_arm_l", &"shoulder_l", &"elbow_l", &"limb", 0.058, 0.043, 1.0, &"arms"],
	[&"upper_arm_r", &"shoulder_r", &"elbow_r", &"limb", 0.058, 0.043, 1.0, &"arms"],
	[&"forearm_l", &"elbow_l", &"wrist_l", &"limb", 0.045, 0.032, 1.0, &"arms"],
	[&"forearm_r", &"elbow_r", &"wrist_r", &"limb", 0.045, 0.032, 1.0, &"arms"],
	[&"hand_l", &"wrist_l", &"hand_l", &"slab", 0.080, 0.080, 0.36, &"arms"],
	[&"hand_r", &"wrist_r", &"hand_r", &"slab", 0.080, 0.080, 0.36, &"arms"],
	[&"thigh_l", &"hip_l", &"knee_l", &"limb", 0.088, 0.060, 1.0, &"legs"],
	[&"thigh_r", &"hip_r", &"knee_r", &"limb", 0.088, 0.060, 1.0, &"legs"],
	[&"shin_l", &"knee_l", &"ankle_l", &"limb", 0.060, 0.040, 1.0, &"legs"],
	[&"shin_r", &"knee_r", &"ankle_r", &"limb", 0.060, 0.040, 1.0, &"legs"],
	[&"foot_l", &"ankle_l", &"toe_l", &"slab", 0.095, 0.095, 0.62, &"legs"],
	[&"foot_r", &"ankle_r", &"toe_r", &"slab", 0.095, 0.095, 0.62, &"legs"],
]

## [joint, radius, group]: the visible ball at each joint.
const BALLS: Array = [
	[&"shoulder_l", 0.068, &"arms"], [&"shoulder_r", 0.068, &"arms"],
	[&"elbow_l", 0.047, &"arms"], [&"elbow_r", 0.047, &"arms"],
	[&"wrist_l", 0.035, &"arms"], [&"wrist_r", 0.035, &"arms"],
	[&"hip_l", 0.084, &"legs"], [&"hip_r", 0.084, &"legs"],
	[&"knee_l", 0.062, &"legs"], [&"knee_r", 0.062, &"legs"],
	[&"ankle_l", 0.046, &"legs"], [&"ankle_r", 0.046, &"legs"],
	[&"pelvis", 0.150, &"torso"],
]

static var _mesh_cache: Dictionary[String, Mesh] = {}
static var _index: Dictionary[StringName, int] = {}
static var _part_from: PackedInt32Array = []
static var _part_to: PackedInt32Array = []
static var _ball_at: PackedInt32Array = []

var material: Material
var body_scale: float = 1.0

var _part_nodes: Array[MeshInstance3D] = []
var _ball_nodes: Array[MeshInstance3D] = []
var _head: MeshInstance3D
var _groups: Dictionary[StringName, Array] = {}


static func index_of(joint: StringName) -> int:
	if _index.is_empty():
		for i: int in JOINTS.size():
			_index[JOINTS[i]] = i
	return _index[joint]


static func create(parent: Node, body_material: Material, scale_factor: float = 1.0) -> Humanoid:
	var h := Humanoid.new()
	h.material = body_material
	h.body_scale = scale_factor
	parent.add_child(h)
	return h


static func _cache_indices() -> void:
	if not _part_from.is_empty():
		return
	for part: Array in PARTS:
		_part_from.append(index_of(part[1]))
		_part_to.append(index_of(part[2]))
	for ball: Array in BALLS:
		_ball_at.append(index_of(ball[0]))


func _ready() -> void:
	_cache_indices()
	top_level = true
	global_transform = Transform3D.IDENTITY
	for part: Array in PARTS:
		var mesh: Mesh
		if part[3] == &"slab":
			mesh = _cached_box(part[4], part[6])
		else:
			mesh = _cached_tube(part[4], part[5])
		_part_nodes.append(_instance(mesh, part[7]))
	for ball: Array in BALLS:
		_ball_nodes.append(_instance(_cached_ball(), ball[2]))
	_head = _instance(_cached_ball(), &"head")


func _instance(mesh: Mesh, group: StringName) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if not _groups.has(group):
		_groups[group] = []
	_groups[group].append(mi)
	return mi


## Hides a whole group: &"head", &"arms", &"legs" or &"torso". The player hides head and arms
## so the first-person camera and viewmodel arms are not fighting the body.
func set_group_visible(group: StringName, shown: bool) -> void:
	for node: MeshInstance3D in _groups.get(group, []):
		node.visible = shown


static func _cached_tube(radius_from: float, radius_to: float) -> Mesh:
	var key: String = "tube_%.3f_%.3f" % [radius_from, radius_to]
	if not _mesh_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = radius_from
		mesh.top_radius = radius_to
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 0
		_mesh_cache[key] = mesh
	return _mesh_cache[key]


static func _cached_box(width: float, depth_ratio: float) -> Mesh:
	var key: String = "box_%.3f_%.3f" % [width, depth_ratio]
	if not _mesh_cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, 1.0, width * depth_ratio)
		_mesh_cache[key] = mesh
	return _mesh_cache[key]


static func _cached_ball() -> Mesh:
	if not _mesh_cache.has("ball"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 10
		mesh.rings = 6
		_mesh_cache["ball"] = mesh
	return _mesh_cache["ball"]


# ---------------------------------------------------------------- drawing

## Lays every part between its two joints. `joints` are world positions in JOINTS order.
func apply(joints: PackedVector3Array) -> void:
	var across_shoulders: Vector3 = joints[index_of(&"shoulder_r")] - joints[index_of(&"shoulder_l")]
	var across_hips: Vector3 = joints[index_of(&"hip_r")] - joints[index_of(&"hip_l")]
	for i: int in PARTS.size():
		var part: Array = PARTS[i]
		var a: Vector3 = joints[_part_from[i]]
		var b: Vector3 = joints[_part_to[i]]
		var side: Vector3 = across_hips if part[7] == &"legs" or part[0] == &"belly" else across_shoulders
		var depth: float = part[6] if part[3] == &"torso" else 1.0
		_stretch(_part_nodes[i], a, b, side, depth)
	for i: int in BALLS.size():
		var ball: Array = BALLS[i]
		var radius: float = ball[1] * body_scale
		var basis := Basis.from_scale(Vector3.ONE * radius)
		if ball[0] == &"pelvis":
			var x: Vector3 = across_hips.normalized() if across_hips.length() > 0.001 else Vector3.RIGHT
			var up: Vector3 = (joints[index_of(&"spine")] - joints[index_of(&"pelvis")]).normalized()
			var z: Vector3 = x.cross(up).normalized()
			basis = Basis(x * radius * 1.12, up * radius * 0.62, z * radius * 0.72)
		_ball_nodes[i].global_transform = Transform3D(basis, joints[_ball_at[i]])
	# The skull: taller than wide, sitting on top of the neck and tilted with it.
	var neck_dir: Vector3 = (joints[index_of(&"head")] - joints[index_of(&"neck")]).normalized()
	var head_x: Vector3 = (across_shoulders - neck_dir * across_shoulders.dot(neck_dir)).normalized()
	if head_x.length() < 0.5:
		head_x = Vector3.RIGHT
	var head_z: Vector3 = head_x.cross(neck_dir).normalized()
	var r: float = 0.112 * body_scale
	_head.global_transform = Transform3D(Basis(head_x * r * 0.92, neck_dir * r * 1.16, head_z * r * 1.02),
		joints[index_of(&"head")] + neck_dir * 0.03 * body_scale)


## Stretches a unit-height mesh (its Y axis) from `a` to `b`. `side` fixes the roll.
func _stretch(node: MeshInstance3D, a: Vector3, b: Vector3, side: Vector3, depth: float) -> void:
	var along: Vector3 = b - a
	var length: float = along.length()
	if length < 0.001:
		return
	var y: Vector3 = along / length
	var x: Vector3 = side - y * side.dot(y)
	if x.length() < 0.001:
		x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	node.global_transform = Transform3D(Basis(x * body_scale, y * length, z * body_scale * depth), (a + b) * 0.5)


# ---------------------------------------------------------------- posing

static func rest_local() -> PackedVector3Array:
	var out := PackedVector3Array()
	for joint: StringName in JOINTS:
		out.append(REST[joint])
	return out


static func to_world(local: PackedVector3Array, xform: Transform3D, scale_factor: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(local.size())
	for i: int in local.size():
		out[i] = xform * (local[i] * scale_factor)
	return out


## Forward kinematics for a living body, in local metres.
##   walk_phase, walk_amount: the stride cycle and how much of it to show (0 standing, 1 running)
##   aim_right, aim_left: 0 arm hanging, 1 arm up and pointing. Both at 1 is a two-handed hold.
##   stagger: 0 upright, 1 bent over backwards from a hit
## Joint names for each side, so pose() never builds a name at runtime.
const LEG: Dictionary[StringName, Array] = {
	&"l": [&"hip_l", &"knee_l", &"ankle_l", &"toe_l"], &"r": [&"hip_r", &"knee_r", &"ankle_r", &"toe_r"],
}
const ARM: Dictionary[StringName, Array] = {
	&"l": [&"shoulder_l", &"elbow_l", &"wrist_l", &"hand_l"], &"r": [&"shoulder_r", &"elbow_r", &"wrist_r", &"hand_r"],
}


static func pose(walk_phase: float, walk_amount: float, aim_right: float, aim_left: float, stagger: float) -> PackedVector3Array:
	var j: Dictionary[StringName, Vector3] = {}
	var pelvis_rest: Vector3 = REST[&"pelvis"]
	j[&"pelvis"] = pelvis_rest

	# Legs: thigh swings, knee only ever bends backwards, foot stays square to the shin.
	for side: StringName in [&"l", &"r"]:
		var phase: float = walk_phase + (0.0 if side == &"l" else PI)
		var leg: Array = LEG[side]
		var hip: Vector3 = REST[leg[0]]
		var knee_rest: Vector3 = REST[leg[1]]
		var ankle_rest: Vector3 = REST[leg[2]]
		var thigh_len: float = hip.distance_to(knee_rest)
		var shin_len: float = knee_rest.distance_to(ankle_rest)
		var swing: float = sin(phase) * 0.62 * walk_amount
		var bend: float = (0.06 + maxf(0.0, -cos(phase)) * 1.05) * walk_amount + 0.03 + stagger * 0.35
		var knee: Vector3 = hip + Basis(Vector3.RIGHT, swing) * Vector3.DOWN * thigh_len
		var ankle: Vector3 = knee + Basis(Vector3.RIGHT, swing - bend) * Vector3.DOWN * shin_len
		var toe: Vector3 = ankle + Basis(Vector3.RIGHT, (swing - bend) * 0.6) * Vector3(0, -0.03, -0.22)
		j[leg[0]] = hip
		j[leg[1]] = knee
		j[leg[2]] = ankle
		j[leg[3]] = toe

	# Upper body leans: forward a touch when running, back hard when staggered.
	var lean := Basis(Vector3.RIGHT, -0.10 * walk_amount + 0.45 * stagger)
	for joint: StringName in [&"spine", &"chest", &"neck", &"head", &"shoulder_l", &"shoulder_r"]:
		j[joint] = pelvis_rest + lean * (REST[joint] - pelvis_rest)
	j[&"head"] = j[&"neck"] + lean * Basis(Vector3.RIGHT, 0.35 * stagger) * (REST[&"head"] - REST[&"neck"])

	# Arms: shoulder raise, elbow bend, and a turn toward the centre line for a two-handed hold.
	for side: StringName in [&"l", &"r"]:
		var sign: float = -1.0 if side == &"l" else 1.0
		var aim: float = aim_left if side == &"l" else aim_right
		var phase: float = walk_phase + (PI if side == &"l" else 0.0)
		var raise: float = lerpf(sin(phase) * 0.55 * walk_amount - 0.25 * stagger, 1.42 if side == &"r" else 1.22, aim)
		var elbow_bend: float = lerpf(0.18 + 0.45 * walk_amount + 0.5 * stagger, 0.14 if side == &"r" else 0.42, aim)
		var inward: float = lerpf(0.0, 0.10 if side == &"r" else 0.62, aim) + 0.35 * stagger
		var splay: float = lerpf(0.10, 0.0, aim)
		var turn := Basis(Vector3.UP, inward * sign) * Basis(Vector3.FORWARD, -splay * sign)
		var arm: Array = ARM[side]
		var shoulder: Vector3 = j[arm[0]]
		var upper_len: float = (REST[arm[0]] as Vector3).distance_to(REST[arm[1]])
		var fore_len: float = (REST[arm[1]] as Vector3).distance_to(REST[arm[2]])
		var hand_len: float = (REST[arm[2]] as Vector3).distance_to(REST[arm[3]])
		var elbow: Vector3 = shoulder + lean * turn * Basis(Vector3.RIGHT, raise) * Vector3.DOWN * upper_len
		var fore_dir: Vector3 = lean * turn * Basis(Vector3.RIGHT, raise + elbow_bend) * Vector3.DOWN
		j[arm[1]] = elbow
		j[arm[2]] = elbow + fore_dir * fore_len
		j[arm[3]] = elbow + fore_dir * (fore_len + hand_len)

	# Plant the lower foot on the ground. This is also what makes the body bob as it walks.
	var lowest: float = minf(j[&"ankle_l"].y, j[&"ankle_r"].y)
	var lift: float = REST[&"ankle_l"].y - lowest
	var out := PackedVector3Array()
	for joint: StringName in JOINTS:
		out.append(j[joint] + Vector3(0, lift, 0))
	return out
