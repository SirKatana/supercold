class_name Cleaner
extends CharacterBody3D
## The building's cleaner, in overalls, cap and yellow gloves, with a broom.
##
## Spill something (pour a bucket, smash a coffee mug) and he comes out of the lift you arrived
## in, walks to the mess, mops it up, stands a wet-floor sign on it, says what he thinks, and
## goes back. He keeps count. On the fifth spill of a floor he has had enough: he comes for the
## player instead, and a swing of the broom kills. He is slower than the player, so he can be
## outrun, and he dies like anyone else. Until then he is nobody's enemy and never counts toward
## clearing the floor.

signal mopped(puddle: Puddle)
signal snapped
signal left

enum Mode { WALKING_TO_SPILL, MOPPING, LEAVING, HUNTING, SWINGING, STAGGERED }

const T: Tuning = preload("res://data/tuning.tres")

var mode: Mode = Mode.LEAVING
var alive: bool = true
var hostile: bool = false
var hp: int = 3
var skin: Humanoid
var joints: PackedVector3Array = []
var voice: HelperVoice
var jobs: Array[Puddle] = []

var _home: Vector3
var _agent: NavigationAgent3D
var _hand: Node3D
var _cap: MeshInstance3D
var _belt: MeshInstance3D
var _gloves: Array[MeshInstance3D] = []
var _walk_phase: float = 0.0
var _moving: float = 0.0
var _clock: float = 0.0
var _sweep: float = 0.0
var _raise: float = 0.0
var _stagger: float = 0.0


func _ready() -> void:
	add_to_group(&"cleaners")
	collision_layer = 256      # like the helper and the guard: bullets stop on him, nobody targets him
	collision_mask = 1
	hp = T.cleaner_hp
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	skin = Humanoid.create(self, Mats.overalls(), 1.0)
	_cap = _accessory(MeshKit.cached(&"cleaner_cap", _model_cap))
	_belt = _accessory(MeshKit.cached(&"cleaner_belt", _model_belt))
	for i: int in 2:
		_gloves.append(_accessory(MeshKit.cached(&"cleaner_glove", _model_glove)))
	_hand = Node3D.new()
	_hand.top_level = true
	add_child(_hand)
	var broom := MeshInstance3D.new()
	broom.mesh = MeshKit.cached(&"cleaner_broom", _model_broom)
	_hand.add_child(broom)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.5
	_agent.avoidance_enabled = false
	add_child(_agent)
	voice = HelperVoice.new()
	voice.name = "Voice"
	add_child(voice)
	_pose()


func _accessory(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A soft cap with a peak. Origin at the centre of the skull, -Z forward.
static func _model_cap(kit: MeshKit) -> void:
	kit.tube(0.118, 0.124, 0.070, Vector3(0, 0.105, 0.0), Mats.overalls_dark(), false, 16)
	kit.box(Vector3(0.160, 0.012, 0.100), Vector3(0, 0.078, -0.150), Mats.overalls_dark(), Vector3(0.16, 0, 0))
	kit.box(Vector3(0.060, 0.030, 0.006), Vector3(0, 0.105, -0.122), Mats.paper())      # company patch


## Bib, utility belt, spray bottle, rag and a name tag. Origin at the chest joint, -Z forward.
static func _model_belt(kit: MeshKit) -> void:
	kit.box(Vector3(0.240, 0.260, 0.012), Vector3(0, 0.020, -0.128), Mats.overalls_dark())           # bib
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.030, 0.300, 0.250), Vector3(0.090 * side, 0.200, -0.010), Mats.overalls_dark(), Vector3(0.0, 0, 0))   # straps
		kit.tube(0.010, 0.010, 0.010, Vector3(0.090 * side, 0.130, -0.136), Mats.brass(), true, 8)   # buckles
	kit.box(Vector3(0.070, 0.028, 0.004), Vector3(-0.070, 0.090, -0.136), Mats.paper())              # name tag
	kit.box(Vector3(0.390, 0.050, 0.290), Vector3(0, -0.235, 0), Mats.rubber())                      # belt
	kit.tube(0.028, 0.034, 0.130, Vector3(0.175, -0.290, -0.060), Mats.tumbler(), false, 10)         # spray bottle
	kit.box(Vector3(0.030, 0.040, 0.060), Vector3(0.175, -0.205, -0.080), Mats.ceramic())            # its trigger head
	kit.box(Vector3(0.090, 0.170, 0.012), Vector3(-0.170, -0.320, -0.090), Mats.rubber_yellow(), Vector3(0.1, 0, 0.15))   # rag


static func _model_glove(kit: MeshKit) -> void:
	kit.box(Vector3(0.095, 0.170, 0.050), Vector3.ZERO, Mats.rubber_yellow())
	kit.tube(0.042, 0.048, 0.060, Vector3(0, 0.105, 0), Mats.rubber_yellow(), false, 10)      # the cuff


## A yard broom. It lies along the forearm: the head is out at -Z, the grip end behind the hand.
static func _model_broom(kit: MeshKit) -> void:
	kit.tube(0.014, 0.014, 1.45, Vector3(0, 0, -0.40), Mats.wood(), true, 8)
	kit.box(Vector3(0.36, 0.045, 0.060), Vector3(0, 0, -1.13), Mats.wood_dark())
	kit.box(Vector3(0.34, 0.030, 0.150), Vector3(0, 0, -1.23), Mats.bristle())
	kit.box(Vector3(0.30, 0.022, 0.040), Vector3(0, 0, -1.32), Mats.bristle())


func say(id: StringName) -> void:
	voice.shut_up()
	voice._current_priority = -1
	voice.say_line(id, HelperVoice.Priority.IMPORTANT)


## `at_home` is where he comes in and goes out: the mouth of the arrival lift.
func report_for_duty(at_home: Vector3) -> void:
	_home = at_home
	global_position = at_home


## Something was spilled. `count` is how many that makes on this floor.
func call_out(puddle: Puddle, count: int) -> void:
	if not alive:
		return
	if count >= T.cleaner_strikes:
		_snap()
		return
	jobs.append(puddle)
	say(StringName("cleaner_%d" % clampi(count, 1, T.cleaner_strikes - 1)))
	if mode == Mode.LEAVING:
		mode = Mode.WALKING_TO_SPILL


func _snap() -> void:
	if hostile:
		return
	hostile = true
	mode = Mode.HUNTING
	collision_layer = 4      # now he is a target like any dude: punches, knives and thrown mugs land
	say(&"cleaner_snap")
	snapped.emit()


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var wd: float = TimeManager.world_delta(delta)
	_moving = 0.0
	_stagger = maxf(0.0, _stagger - wd)
	if _stagger > 0.0:
		_pose()
		return
	match mode:
		Mode.WALKING_TO_SPILL:
			_next_job()
			if jobs.is_empty():
				mode = Mode.LEAVING
			elif _flat(jobs[0].global_position) <= maxf(0.9, jobs[0].radius * 0.6):
				mode = Mode.MOPPING
				_clock = 0.0
			else:
				_walk(jobs[0].global_position, T.cleaner_speed, wd, delta)
		Mode.MOPPING:
			_next_job()
			if jobs.is_empty():
				mode = Mode.LEAVING
			else:
				_clock += wd
				_sweep += wd * 7.0
				_face(jobs[0].global_position, wd)
				if _clock >= T.cleaner_mop_seconds:
					var done: Puddle = jobs.pop_front()
					WetFloorSign.stand(Game.entities_root(self), done.global_position)
					done.mop_up(0.6)
					mopped.emit(done)
					say(&"cleaner_done")
					mode = Mode.WALKING_TO_SPILL
		Mode.LEAVING:
			if _flat(_home) < 0.6:
				left.emit()
				queue_free()
				return
			_walk(_home, T.cleaner_speed, wd, delta)
		Mode.HUNTING:
			var p: Player = _player()
			if p != null and p.alive:
				if _flat(p.global_position) <= T.cleaner_swing_range * 0.85:
					mode = Mode.SWINGING
					_clock = 0.0
				else:
					_walk(p.global_position, T.cleaner_chase_speed, wd, delta)
		Mode.SWINGING:
			var target: Player = _player()
			_clock += wd
			if target != null:
				_face(target.global_position, wd)
			_raise = clampf(_clock / T.cleaner_windup, 0.0, 1.0)
			if _clock >= T.cleaner_windup:
				Sfx.play(&"punch", global_position)
				if target != null and target.alive and _flat(target.global_position) <= T.cleaner_swing_range:
					target.die()
				_raise = 0.0
				_clock = 0.0
				mode = Mode.HUNTING
	_pose()


## Drops jobs that dried up or were freed while he was on his way.
func _next_job() -> void:
	while not jobs.is_empty() and (not is_instance_valid(jobs[0]) or jobs[0].is_queued_for_deletion()):
		jobs.pop_front()


func _flat(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _face(point: Vector3, step: float) -> void:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, 9.0 * step))


func _walk(target: Vector3, speed: float, step: float, delta: float) -> void:
	_agent.target_position = target
	var next: Vector3 = _agent.get_next_path_position()
	var flat := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if flat.length() < 0.05:
		flat = Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() < 0.05 or delta <= 0.0:
		return
	_face(global_position + flat, step)
	velocity = flat.normalized() * speed * (step / delta)
	move_and_slide()
	_moving = clampf(speed / 3.2, 0.6, 1.5)
	_walk_phase += step * 8.0 * _moving


func _pose() -> void:
	var mopping: bool = mode == Mode.MOPPING
	# Carried low across the body; pushed back and forth when mopping; up over the head to strike.
	var right: float = 0.30
	var bend: float = 0.0
	if mopping:
		right = 0.34 + 0.10 * sin(_sweep)
		bend = 0.30 + 0.06 * sin(_sweep)
	if mode == Mode.SWINGING:
		right = lerpf(0.30, 1.0, _raise)
	var left: float = 0.30 if mopping else 0.0
	var local: PackedVector3Array = Humanoid.pose(_walk_phase, _moving, right, left, clampf(_stagger, 0.0, 1.0), mode == Mode.SWINGING, 0.0, bend)
	if mode == Mode.SWINGING:
		# Right over the top: lift the whole arm a little more than an aim does.
		for joint: StringName in [&"elbow_r", &"wrist_r", &"hand_r"]:
			local[Humanoid.index_of(joint)] += Vector3(0, 0.22 * _raise, 0.10 * _raise)
	joints = Humanoid.to_world(local, global_transform, 1.0)
	skin.apply(joints)
	_cap.global_transform = skin.shades_transform()
	var chest: Vector3 = joints[Humanoid.index_of(&"chest")]
	var up: Vector3 = (joints[Humanoid.index_of(&"neck")] - joints[Humanoid.index_of(&"spine")]).normalized()
	var across: Vector3 = (joints[Humanoid.index_of(&"shoulder_r")] - joints[Humanoid.index_of(&"shoulder_l")]).normalized()
	_belt.global_transform = Transform3D(Basis(across, up, across.cross(up).normalized()), chest)
	for i: int in 2:
		var wrist: Vector3 = joints[Humanoid.index_of(&"wrist_r" if i == 0 else &"wrist_l")]
		var hand: Vector3 = joints[Humanoid.index_of(&"hand_r" if i == 0 else &"hand_l")]
		var along: Vector3 = (wrist - hand).normalized()
		var ref: Vector3 = Vector3.UP if absf(along.y) < 0.9 else Vector3.FORWARD
		var x: Vector3 = ref.cross(along).normalized()
		_gloves[i].global_transform = Transform3D(Basis(x, along, x.cross(along)), hand.lerp(wrist, 0.35))
	var w: Vector3 = joints[Humanoid.index_of(&"wrist_r")]
	var forward: Vector3 = (w - joints[Humanoid.index_of(&"elbow_r")]).normalized()
	var hand_up: Vector3 = Vector3.UP if absf(forward.y) < 0.95 else -global_transform.basis.z
	_hand.global_transform = Transform3D(Basis.looking_at(forward, hand_up), w.lerp(joints[Humanoid.index_of(&"hand_r")], 0.5))


# ------------------------------------------------------------------ getting hurt

func on_bullet_hit(_bullet: Node, _point: Vector3, normal: Vector3) -> bool:
	_hurt(T.cleaner_hp, -normal)
	return false


func on_thrown_hit(item: Pickup) -> void:
	_hurt(1, item.velocity.normalized())


func on_punched(by: Node, _at: Vector3) -> void:
	_hurt(1, (global_position - (by as Node3D).global_position).normalized() if by is Node3D else Vector3.ZERO)


func on_laser(direction: Vector3) -> void:
	_hurt(T.cleaner_hp, direction)


func on_explosion(centre: Vector3) -> void:
	_hurt(T.cleaner_hp, (global_position - centre).normalized())


func _hurt(amount: int, push: Vector3) -> void:
	if not alive:
		return
	hp -= amount
	if hp > 0:
		_stagger = 1.0
		_snap()      # hit a man who is mopping your mess and you have skipped to strike five
		return
	alive = false
	collision_layer = 0
	voice.shut_up()
	Ragdoll.spawn(Game.entities_root(self), joints, 1.0, push * 3.0 + Vector3.UP, Mats.overalls(), 1.0)
	Sfx.play(&"death", global_position)
	queue_free()
