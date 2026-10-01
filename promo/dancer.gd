extends Node3D
## One dancer for the promo: the game's own Humanoid, posed by inverse kinematics instead of the
## walk cycle. Every move is a pure function of the beat, so any frame can be rendered alone.

const UPPER_ARM: float = 0.295
const FOREARM: float = 0.265
const THIGH: float = 0.431
const SHIN: float = 0.422

## Real clothes, built from the very same meshes the characters wear in the game: the
## gentleman's hat, face and suit, the cleaner's cap, belt and gloves, the guard's cap and
## vest. Dressing a dancer in a cylinder and calling it a top hat was a lie.
var wearing: StringName = &""

var skin: Humanoid
var body_scale: float = 1.0
var hand_anchor: Node3D
var joints: PackedVector3Array = []
## Mirrors left and right, so two dancers side by side are not clones.
var mirrored: bool = false

var _head_gear: MeshInstance3D
var _face: MeshInstance3D
var _torso_gear: MeshInstance3D
var _shoes: Array[MeshInstance3D] = []
var _cuffs: Array[MeshInstance3D] = []


func setup(material: Material, scale_factor: float, shades: bool) -> void:
	body_scale = scale_factor
	skin = Humanoid.create(self, material, scale_factor)
	skin.set_sunglasses(shades)
	hand_anchor = Node3D.new()
	hand_anchor.top_level = true
	add_child(hand_anchor)


## Puts the real character's kit on this dancer. `kind` is &"gentleman", &"cleaner" or
## &"guard". Shoes, cuffs and gloves come in pairs, right first.
func wear(kind: StringName) -> void:
	wearing = kind
	match kind:
		&"gentleman":
			skin.set_group_material(&"arms", Mats.gentleman_coat())
			skin.set_group_material(&"torso", Mats.gentleman_coat())
			skin.set_group_material(&"legs", Mats.gentleman_trousers())
			skin.set_group_material(&"head", Mats.gentleman_skin())
			_head_gear = _accessory(MeshKit.cached(&"gentleman_hat", Gentleman._model_hat))
			_face = _accessory(MeshKit.cached(&"gentleman_face", Gentleman._model_face))
			_torso_gear = _accessory(MeshKit.cached(&"gentleman_suit", Gentleman._model_suit))
			for i: int in 2:
				_shoes.append(_accessory(MeshKit.cached(&"gentleman_shoe", Gentleman._model_shoe)))
				_cuffs.append(_accessory(MeshKit.cached(&"gentleman_cuff", Gentleman._model_cuff)))
		&"cleaner":
			skin.set_group_material(&"arms", Mats.overalls())
			skin.set_group_material(&"torso", Mats.overalls())
			skin.set_group_material(&"legs", Mats.overalls_dark())
			skin.set_group_material(&"head", Mats.pink())
			_head_gear = _accessory(MeshKit.cached(&"cleaner_cap", Cleaner._model_cap))
			_torso_gear = _accessory(MeshKit.cached(&"cleaner_belt", Cleaner._model_belt))
			for i: int in 2:
				_cuffs.append(_accessory(MeshKit.cached(&"cleaner_glove", Cleaner._model_glove)))
		&"guard":
			skin.set_group_material(&"arms", Mats.security_suit())
			skin.set_group_material(&"torso", Mats.security_suit())
			skin.set_group_material(&"legs", Mats.security_suit())
			_head_gear = _accessory(MeshKit.cached(&"guard_cap", SecurityGuard._model_cap))
			_torso_gear = _accessory(MeshKit.cached(&"guard_vest", SecurityGuard._model_vest))


func _accessory(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.top_level = true      # placed from the joints, not carried by the node's transform
	add_child(mi)
	return mi


## The same placement the characters use in the game: head gear on the shades frame, the
## suit or vest on the chest, shoes on the ankles, cuffs and gloves at the wrists.
func _place_what_is_worn() -> void:
	if wearing == &"" or joints.is_empty():
		return
	if _head_gear != null:
		_head_gear.global_transform = skin.shades_transform()
	if _face != null:
		_face.global_transform = skin.shades_transform()
	var chest: Vector3 = joints[Humanoid.index_of(&"chest")]
	var up: Vector3 = (joints[Humanoid.index_of(&"neck")] - joints[Humanoid.index_of(&"spine")]).normalized()
	var across: Vector3 = (joints[Humanoid.index_of(&"shoulder_r")] - joints[Humanoid.index_of(&"shoulder_l")]).normalized()
	if _torso_gear != null:
		_torso_gear.global_transform = Transform3D(Basis(across, up, across.cross(up).normalized()), chest)
	for i: int in _shoes.size():
		var ankle: Vector3 = joints[Humanoid.index_of(&"ankle_r" if i == 0 else &"ankle_l")]
		var toe: Vector3 = joints[Humanoid.index_of(&"toe_r" if i == 0 else &"toe_l")]
		var forward: Vector3 = (toe - ankle).normalized()
		if forward.length() > 0.5:
			_shoes[i].global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), ankle + Vector3(0, 0.02, 0))
	for i: int in _cuffs.size():
		var wrist: Vector3 = joints[Humanoid.index_of(&"wrist_r" if i == 0 else &"wrist_l")]
		var elbow: Vector3 = joints[Humanoid.index_of(&"elbow_r" if i == 0 else &"elbow_l")]
		var along: Vector3 = (wrist - elbow).normalized()
		var ref: Vector3 = Vector3.UP if absf(along.y) < 0.9 else Vector3.FORWARD
		var x_axis: Vector3 = ref.cross(along).normalized()
		_cuffs[i].global_transform = Transform3D(Basis(x_axis, along, x_axis.cross(along)), wrist.lerp(elbow, 0.22))


func hold(gun: Node3D) -> void:
	gun.call(&"attach_to", hand_anchor)


func muzzle() -> Vector3:
	return hand_anchor.global_position - hand_anchor.global_transform.basis.z.normalized() * 0.55


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## `beats` is the song position in quarter notes. `blend` fades the move in from standing.
func dance(move: StringName, beats: float, blend: float = 1.0, recoil: float = 0.0) -> void:
	var R: Dictionary[StringName, Vector3] = Humanoid.REST
	var drop: float = 0.0          # pelvis down
	var sway: float = 0.0          # pelvis sideways
	var lift: float = 0.0          # pelvis up (a hop)
	var lean: float = 0.0          # upper body pitch, + forwards
	var roll: float = 0.0          # upper body roll
	var twist: float = 0.0         # upper body yaw
	var shrug_up: float = 0.0
	var on_beat: float = pow(absf(cos(PI * beats)), 2.0)
	var hand_r: Vector3 = R[&"wrist_r"]
	var hand_l: Vector3 = R[&"wrist_l"]
	var foot_r: Vector3 = R[&"ankle_r"]
	var foot_l: Vector3 = R[&"ankle_l"]
	var pole_r := Vector3(0.6, -0.6, 0.5)
	var pole_l := Vector3(-0.6, -0.6, 0.5)
	var hip_r: Vector3 = R[&"hip_r"]
	var hip_l: Vector3 = R[&"hip_l"]

	match move:
		&"still":
			drop = 0.006 * sin(beats * 0.9)
		&"tap":
			# Standing still, one foot keeping time. He cannot help it.
			foot_r += Vector3(0.04, 0.05 * on_beat, -0.06)
			drop = 0.01 * on_beat
		&"cancan":
			var u: float = fposmod(beats, 2.0) / 2.0
			var h: float = pow(sin(PI * u), 1.4)
			var right_leg: bool = fposmod(beats, 4.0) < 2.0
			var goal := Vector3(0.0, -0.85 + 1.40 * h, -(0.05 + 0.80 * h))
			if right_leg:
				foot_r = hip_r + goal
			else:
				foot_l = hip_l + goal
			lift = 0.05 * h
			drop = 0.03 * on_beat
			lean = -0.20 * h
			hand_r = hip_r + Vector3(0.13, 0.06, -0.02)
			hand_l = hip_l + Vector3(-0.13, 0.06, -0.02)
			pole_r = Vector3(1.0, 0.0, 0.35)
			pole_l = Vector3(-1.0, 0.0, 0.35)
			roll = 0.06 * sin(PI * beats * 0.5)
		&"cha_cha":
			# Cha-cha-cha: three quick steps on 4-and-1, then a rock step on 2 and 3. The hips
			# lead and the shoulders stay quiet, which is what makes it read as a cha-cha
			# rather than a jog on the spot. The feet are offsets from where they already
			# stand: hang them off the hips instead and the whole dancer floats a metre up.
			var count: float = fposmod(beats, 4.0)
			var side: float = 1.0 if fposmod(beats, 8.0) < 4.0 else -1.0
			var quick: float = clampf((count - 3.0) * 2.0, 0.0, 1.0) if count >= 3.0 else 0.0
			var rock: float = maxf(sin(PI * clampf(count, 0.0, 2.0) * 0.5), 0.0)
			sway = 0.075 * side * cos(PI * count * 0.5) + 0.04 * side * quick
			twist = -0.20 * side * cos(PI * count * 0.5)
			drop = 0.03 * on_beat + 0.015 * quick
			lift = 0.012 * quick
			# One foot crosses on the quick steps, the other takes the weight on the rock.
			foot_r += Vector3(0.11 + 0.12 * side * quick, 0.05 * quick, -0.14 * rock)
			foot_l += Vector3(-0.11 + 0.12 * side * quick, 0.05 * (1.0 - quick), 0.09 * rock)
			# Arms out in frame, swinging against the hips. Cuban, not disco.
			hand_r = R[&"shoulder_r"] + Vector3(0.30 - 0.08 * side, 0.10 + 0.06 * on_beat, -0.28)
			hand_l = R[&"shoulder_l"] + Vector3(-0.30 - 0.08 * side, 0.10 + 0.06 * (1.0 - on_beat), -0.28)
			pole_r = Vector3(0.9, -0.3, 0.4)
			pole_l = Vector3(-0.9, -0.3, 0.4)
			roll = 0.045 * side * cos(PI * count * 0.5)
		&"disco":
			var s: float = _ease(0.5 - 0.5 * cos(PI * beats))      # 0 down, 1 up, every two beats
			var up := R[&"shoulder_r"] + Vector3(0.36, 0.52, -0.12)
			var down := hip_l + Vector3(-0.16, -0.02, -0.26)
			hand_r = down.lerp(up, s)
			pole_r = Vector3(0.7, -0.5, 0.6)
			hand_l = hip_l + Vector3(-0.13, 0.06, -0.02)
			pole_l = Vector3(-1.0, 0.0, 0.35)
			sway = 0.09 * (2.0 * s - 1.0)
			twist = 0.35 * (2.0 * s - 1.0)
			drop = 0.05 * on_beat
			foot_l += Vector3(-0.10, 0.0, 0.0)
			foot_r += Vector3(0.10, 0.04 * (1.0 - s), 0.0)
		&"floss":
			var q: float = sin(PI * beats)
			var c: float = 1.0 if fposmod(beats, 2.0) < 1.0 else -1.0
			c *= _ease(minf(fposmod(beats, 1.0), 1.0 - fposmod(beats, 1.0)) * 6.0)
			hand_r = Vector3(0.46 * q + 0.10, 0.93, -0.24 * c)
			hand_l = Vector3(0.46 * q - 0.10, 0.93, 0.24 * c)
			pole_r = Vector3(0.3, 0.2, 1.0)
			pole_l = Vector3(-0.3, 0.2, 1.0)
			sway = -0.13 * q
			roll = -0.10 * q
			drop = 0.03
			foot_l += Vector3(-0.08, 0.0, 0.0)
			foot_r += Vector3(0.08, 0.0, 0.0)
		&"wave":
			var push: float = on_beat
			var side: float = 0.10 * sin(PI * beats * 0.5)
			hand_r = R[&"shoulder_r"] + Vector3(0.10 + side, 0.40 + 0.14 * push, -0.10)
			hand_l = R[&"shoulder_l"] + Vector3(-0.10 + side, 0.40 + 0.14 * push, -0.10)
			pole_r = Vector3(1.0, -0.2, 0.2)
			pole_l = Vector3(-1.0, -0.2, 0.2)
			sway = side
			drop = 0.06 * push
			foot_l += Vector3(-0.09, 0.0, 0.0)
			foot_r += Vector3(0.09, 0.0, 0.0)
		&"gun_up":
			hand_r = R[&"shoulder_r"] + Vector3(0.04, 0.545 - 0.13 * recoil, -0.02)
			pole_r = Vector3(0.4, 0.0, 1.0)
			hand_l = hip_l + Vector3(-0.13, 0.06, -0.02)
			pole_l = Vector3(-1.0, 0.0, 0.35)
			drop = 0.07 * on_beat + 0.03 * recoil
			lean = -0.10 - 0.06 * recoil
			sway = 0.05 * sin(PI * beats * 0.5)
			foot_l += Vector3(-0.12, 0.0, 0.0)
			foot_r += Vector3(0.12, 0.0, 0.0)
		&"shades":
			# Two fingers to the glasses. `recoil` is reused as how far the hand has come up.
			var a: float = _ease(recoil)
			hand_r = R[&"wrist_r"].lerp(R[&"head"] + Vector3(0.13, 0.00, -0.13), a)
			pole_r = Vector3(1.0, -0.3, 0.2)
			twist = 0.0
		&"shrug":
			var a2: float = _ease(recoil)
			hand_r = R[&"wrist_r"].lerp(Vector3(0.50, 1.22, -0.16), a2)
			hand_l = R[&"wrist_l"].lerp(Vector3(-0.50, 1.22, -0.16), a2)
			pole_r = Vector3(0.3, -1.0, 0.3)
			pole_l = Vector3(-0.3, -1.0, 0.3)
			shrug_up = 0.05 * a2
			roll = 0.05 * a2
		&"fever":
			# The pose. One finger at the sky, one hand on the hip, feet apart.
			hand_r = R[&"shoulder_r"] + Vector3(0.34, 0.50, -0.10)
			hand_l = hip_l + Vector3(-0.14, 0.06, -0.02)
			pole_l = Vector3(-1.0, 0.0, 0.35)
			sway = -0.08
			roll = -0.08
			foot_l += Vector3(-0.16, 0.0, 0.0)
			foot_r += Vector3(0.20, 0.0, -0.05)
			drop = 0.02 + 0.015 * on_beat

	if mirrored:
		var swap: Vector3 = hand_r
		hand_r = Vector3(-hand_l.x, hand_l.y, hand_l.z)
		hand_l = Vector3(-swap.x, swap.y, swap.z)
		swap = foot_r
		foot_r = Vector3(-foot_l.x, foot_l.y, foot_l.z)
		foot_l = Vector3(-swap.x, swap.y, swap.z)
		swap = pole_r
		pole_r = Vector3(-pole_l.x, pole_l.y, pole_l.z)
		pole_l = Vector3(-swap.x, swap.y, swap.z)
		sway = -sway
		roll = -roll
		twist = -twist

	# Fade from standing.
	var b: float = clampf(blend, 0.0, 1.0)
	hand_r = R[&"wrist_r"].lerp(hand_r, b)
	hand_l = R[&"wrist_l"].lerp(hand_l, b)
	foot_r = R[&"ankle_r"].lerp(foot_r, b)
	foot_l = R[&"ankle_l"].lerp(foot_l, b)
	drop *= b; sway *= b; lift *= b; lean *= b; roll *= b; twist *= b

	var j: Dictionary[StringName, Vector3] = {}
	var pelvis: Vector3 = R[&"pelvis"] + Vector3(sway, lift - drop, 0.0)
	j[&"pelvis"] = pelvis
	var upper := Basis(Vector3.UP, twist) * Basis(Vector3.RIGHT, -lean) * Basis(Vector3.FORWARD, roll)
	for joint: StringName in [&"spine", &"chest", &"neck", &"head", &"shoulder_l", &"shoulder_r"]:
		j[joint] = pelvis + upper * (R[joint] - R[&"pelvis"])
	j[&"shoulder_l"] += Vector3(0, shrug_up, 0)
	j[&"shoulder_r"] += Vector3(0, shrug_up, 0)
	j[&"hip_l"] = pelvis + (hip_l - R[&"pelvis"])
	j[&"hip_r"] = pelvis + (hip_r - R[&"pelvis"])

	for side: StringName in [&"l", &"r"]:
		var right: bool = side == &"r"
		var shoulder: Vector3 = j[&"shoulder_r"] if right else j[&"shoulder_l"]
		var arm: Array[Vector3] = Humanoid.two_bone(shoulder, hand_r if right else hand_l, UPPER_ARM, FOREARM, pole_r if right else pole_l)
		var along: Vector3 = (arm[1] - arm[0]).normalized()
		j[&"elbow_r" if right else &"elbow_l"] = arm[0]
		j[&"wrist_r" if right else &"wrist_l"] = arm[1]
		j[&"hand_r" if right else &"hand_l"] = arm[1] + along * 0.13
		var hip: Vector3 = j[&"hip_r"] if right else j[&"hip_l"]
		var ankle_goal: Vector3 = foot_r if right else foot_l
		var leg: Array[Vector3] = Humanoid.two_bone(hip, ankle_goal, THIGH, SHIN, Vector3(0.0, 0.25, -1.0))
		j[&"knee_r" if right else &"knee_l"] = leg[0]
		j[&"ankle_r" if right else &"ankle_l"] = leg[1]
		var raised: float = clampf((leg[1].y - 0.10) / 0.35, 0.0, 1.0)
		var flat_toe: Vector3 = leg[1] + Vector3(0, -0.03, -0.205)
		var pointed: Vector3 = leg[1] + (leg[1] - leg[0]).normalized() * 0.205
		j[&"toe_r" if right else &"toe_l"] = flat_toe.lerp(pointed, raised)

	var local := PackedVector3Array()
	for joint: StringName in Humanoid.JOINTS:
		local.append(j[joint])
	joints = Humanoid.to_world(local, global_transform, body_scale)
	skin.apply(joints)
	_place_what_is_worn()

	var wrist: Vector3 = joints[Humanoid.index_of(&"wrist_l" if mirrored else &"wrist_r")]
	var elbow: Vector3 = joints[Humanoid.index_of(&"elbow_l" if mirrored else &"elbow_r")]
	var hand: Vector3 = joints[Humanoid.index_of(&"hand_l" if mirrored else &"hand_r")]
	var forward: Vector3 = (wrist - elbow).normalized()
	var up: Vector3 = Vector3.UP if absf(forward.y) < 0.9 else global_transform.basis.z
	hand_anchor.global_transform = Transform3D(Basis.looking_at(forward, up).scaled(Vector3.ONE * body_scale), wrist.lerp(hand, 0.5))
