class_name Cleaner
extends CharacterBody3D
## The building's cleaner: a pink dude like the rest of the staff, in a grey-blue work shirt with
## a name patch, navy work trousers and cap, yellow rubber gloves, keys on his belt, a yard
## broom, and a yellow mop bucket on wheels that follows him about.
##
## Spill something (pour a bucket, smash a coffee mug) and he comes out of the lift you arrived
## in, walks to the mess, mops it up, stands a wet-floor sign on it, says what he thinks, and
## goes back. He keeps count. On the fifth spill of a floor he has had enough: he comes for the
## player instead, and a swing of the broom kills. He is slower than the player, so he can be
## outrun. He cannot be killed: shoot him and he only turns on whoever did it and shouts WHY!
## He is nobody's enemy until that fifth spill, and never counts toward clearing the floor.

signal mopped(puddle: Puddle)
signal snapped
signal left
signal outraged(at_whom: Node3D)

enum Mode { WALKING_TO_SPILL, MOPPING, LEAVING, HUNTING, SWINGING, STAGGERED }

const T: Tuning = preload("res://data/tuning.tres")

var mode: Mode = Mode.LEAVING
var alive: bool = true
var hostile: bool = false
## Set before he is added to the tree: he is in his own room and you are not meant to be here.
var born_angry: bool = false
## He does nothing at all until he has been told where he comes in and goes out. Running his
## walk before that sent him to the middle of the world and took the engine with him.
var _on_duty: bool = false
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
var _bucket: MeshInstance3D
var _bucket_at: Vector3 = Vector3.INF
var _walk_phase: float = 0.0
var _moving: float = 0.0
var _clock: float = 0.0
var _sweep: float = 0.0
var _raise: float = 0.0
var _stagger: float = 0.0
var _why_left: float = 0.0
var _why_at: Vector3 = Vector3.ZERO
var _last_why: int = -100000


func _ready() -> void:
	add_to_group(&"cleaners")
	if born_angry:
		call_deferred(&"_snap")      # his room, his rules
	collision_layer = 256      # like the helper and the guard: bullets stop on him, nobody targets him
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	skin = Humanoid.create(self, Mats.overalls(), 1.0)
	skin.set_group_material(&"legs", Mats.overalls_dark())      # trousers
	skin.set_group_material(&"head", Mats.pink())               # he works here too
	_bucket = MeshInstance3D.new()
	_bucket.mesh = MeshKit.cached(&"cleaner_mop_bucket", _model_mop_bucket)
	_bucket.top_level = true
	add_child(_bucket)
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


## A work cap: rounded crown, button on top, a stiff peak. Origin at the centre of the skull, -Z forward.
static func _model_cap(kit: MeshKit) -> void:
	var cloth: Material = Mats.overalls_dark()
	kit.tube(0.100, 0.122, 0.060, Vector3(0, 0.072, 0.004), cloth, false, 16)
	kit.tube(0.060, 0.100, 0.030, Vector3(0, 0.117, 0.004), cloth, false, 16)
	kit.tube(0.012, 0.012, 0.010, Vector3(0, 0.136, 0.004), cloth, false, 8)
	kit.box(Vector3(0.150, 0.010, 0.095), Vector3(0, 0.050, -0.150), cloth, Vector3(0.12, 0, 0))
	kit.box(Vector3(0.058, 0.028, 0.006), Vector3(0, 0.082, -0.121), Mats.paper())      # company patch


## What a work shirt has on it, and a belt with a janitor's things. Origin at the chest joint, -Z forward.
static func _model_belt(kit: MeshKit) -> void:
	var navy: Material = Mats.overalls_dark()
	# Collar, a button placket, two chest pockets, the name patch.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.070, 0.035, 0.012), Vector3(0.045 * side, 0.165, -0.118), navy, Vector3(0, 0, 0.5 * side))
		kit.box(Vector3(0.095, 0.085, 0.008), Vector3(0.095 * side, 0.030, -0.128), navy)
		kit.box(Vector3(0.095, 0.022, 0.010), Vector3(0.095 * side, 0.072, -0.129), navy)
	kit.box(Vector3(0.016, 0.300, 0.006), Vector3(0, -0.010, -0.128), navy)
	for i: int in 4:
		kit.tube(0.006, 0.006, 0.004, Vector3(0, 0.110 - i * 0.075, -0.133), Mats.ceramic(), true, 8)
	kit.box(Vector3(0.075, 0.034, 0.004), Vector3(-0.095, 0.105, -0.131), Mats.paper())             # name patch
	kit.box(Vector3(0.065, 0.006, 0.005), Vector3(-0.095, 0.105, -0.133), Mats.book(0))             # the name, stitched in red
	# Belt: keys on a ring, a radio, a spray bottle in its holster, a rag in the back pocket.
	kit.box(Vector3(0.390, 0.045, 0.290), Vector3(0, -0.235, 0), Mats.rubber())
	kit.box(Vector3(0.045, 0.035, 0.012), Vector3(0, -0.235, -0.150), Mats.steel())                 # buckle
	kit.tube(0.030, 0.030, 0.006, Vector3(-0.150, -0.290, -0.110), Mats.brass(), true, 12)          # key ring
	for k: int in 3:
		kit.box(Vector3(0.010, 0.060, 0.004), Vector3(-0.165 + k * 0.015, -0.345, -0.112), Mats.brass(), Vector3(0, 0, -0.25 + k * 0.25))
	kit.box(Vector3(0.045, 0.090, 0.030), Vector3(0.200, -0.215, 0.020), Mats.polymer())            # radio
	kit.tube(0.003, 0.003, 0.060, Vector3(0.210, -0.140, 0.020), Mats.polymer(), false, 6)
	kit.tube(0.028, 0.034, 0.130, Vector3(0.150, -0.300, -0.090), Mats.tumbler(), false, 10)        # spray bottle
	kit.box(Vector3(0.030, 0.040, 0.065), Vector3(0.150, -0.215, -0.110), Mats.ceramic())
	kit.box(Vector3(0.100, 0.150, 0.010), Vector3(-0.090, -0.330, 0.150), Mats.rubber_yellow(), Vector3(-0.1, 0, 0.12))   # rag


static func _model_glove(kit: MeshKit) -> void:
	kit.box(Vector3(0.090, 0.150, 0.048), Vector3.ZERO, Mats.rubber_yellow())
	kit.tube(0.040, 0.050, 0.075, Vector3(0, 0.105, 0), Mats.rubber_yellow(), false, 10)      # the long cuff


## A yard broom. It lies along the forearm: the head is out at -Z, the grip end behind the hand.
## Short enough past the hand that the head rests on the floor, not under it.
static func _model_broom(kit: MeshKit) -> void:
	kit.tube(0.015, 0.015, 1.30, Vector3(0, 0, -0.18), Mats.wood(), true, 8)
	kit.tube(0.019, 0.019, 0.05, Vector3(0, 0, 0.45), Mats.rubber(), true, 8)               # grip cap
	kit.box(Vector3(0.42, 0.055, 0.075), Vector3(0, 0, -0.83), Mats.wood_dark())             # head block
	kit.box(Vector3(0.40, 0.045, 0.130), Vector3(0, 0, -0.925), Mats.bristle())              # bristles
	kit.box(Vector3(0.36, 0.030, 0.050), Vector3(0, 0, -1.010), Mats.bristle())
	for i: int in 7:
		kit.box(Vector3(0.006, 0.047, 0.125), Vector3(-0.18 + i * 0.06, 0, -0.925), Mats.wood_dark())   # rows in the bristles


## The yellow mop bucket on castors, with its wringer and a mop standing in it. Origin on the floor.
static func _model_mop_bucket(kit: MeshKit) -> void:
	var yellow: Material = Mats.mop_bucket_yellow()
	kit.box(Vector3(0.38, 0.30, 0.50), Vector3(0, 0.23, 0), yellow)
	kit.box(Vector3(0.33, 0.02, 0.45), Vector3(0, 0.375, 0), Mats.water())                  # the water in it
	kit.box(Vector3(0.40, 0.03, 0.52), Vector3(0, 0.385, 0), yellow)                        # rim
	kit.box(Vector3(0.33, 0.04, 0.45), Vector3(0, 0.392, 0), Mats.water())
	kit.box(Vector3(0.34, 0.20, 0.20), Vector3(0, 0.49, -0.16), yellow)                     # wringer
	kit.box(Vector3(0.03, 0.34, 0.03), Vector3(0.19, 0.62, -0.16), Mats.polymer(), Vector3(0.35, 0, 0))   # wringer lever
	kit.box(Vector3(0.24, 0.10, 0.004), Vector3(0, 0.22, -0.252), Mats.polymer())           # CAUTION label
	kit.box(Vector3(0.24, 0.10, 0.004), Vector3(0, 0.22, 0.252), Mats.polymer())
	for x: float in [-0.16, 0.16]:
		for z: float in [-0.21, 0.21]:
			kit.tube(0.035, 0.035, 0.03, Vector3(x, 0.035, z), Mats.rubber(), false, 10, Vector3(0, 0, PI * 0.5))   # castors
			kit.box(Vector3(0.02, 0.05, 0.02), Vector3(x, 0.075, z), Mats.steel())
	kit.tube(0.014, 0.014, 1.25, Vector3(0.02, 0.98, 0.10), Mats.wood(), false, 8, Vector3(0.10, 0, 0.06))   # the mop
	kit.box(Vector3(0.20, 0.12, 0.16), Vector3(0.0, 0.40, 0.06), Mats.ceramic())                          # its head, in the water


func say(id: StringName) -> void:
	voice.shut_up()
	voice._current_priority = -1
	voice.say_line(id, HelperVoice.Priority.IMPORTANT)


## Words with no clip behind them: a bubble over his head and nothing spoken. Used for the
## staff room, where fifteen of them shouting the same recorded line would be a wall of noise.
func shout(words: String) -> void:
	voice.shut_up()
	voice._current_priority = -1
	voice.say(words, HelperVoice.Priority.IMPORTANT, [])


## `at_home` is where he comes in and goes out: the mouth of the arrival lift.
func report_for_duty(at_home: Vector3) -> void:
	_home = at_home
	global_position = at_home
	_on_duty = true


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
	if not alive or not _on_duty:
		return
	var wd: float = TimeManager.world_delta(delta)
	_moving = 0.0
	_stagger = maxf(0.0, _stagger - wd)
	if _stagger > 0.0:
		_pose()
		return
	if _why_left > 0.0:
		# Work stops while he tells whoever it was what he thinks of them.
		_why_left -= wd
		_face(_why_at, wd)
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
				# He is back at the lift and about to ride down. Anybody standing in it with him
				# is coming too, which is not where they wanted to go.
				var tag_along: Player = _player()
				if tag_along != null and tag_along.alive \
						and tag_along.global_position.distance_to(global_position) < T.cleaner_lift_share:
					# Do NOT free him here. The level is torn down to build the staff room, and
					# freeing a node and then loading a level from inside the same physics step
					# takes the engine down with it.
					left.emit()
					mode = Mode.WALKING_TO_SPILL
					Game.take_me_to_the_lair.call_deferred(&"cleaner")
					return
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
	if _why_left > 0.0:
		left = 0.82 + 0.10 * sin(Time.get_ticks_msec() * 0.02)      # the fist, shaken
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
	_roll_bucket()
	var w: Vector3 = joints[Humanoid.index_of(&"wrist_r")]
	var forward: Vector3 = (w - joints[Humanoid.index_of(&"elbow_r")]).normalized()
	var hand_up: Vector3 = Vector3.UP if absf(forward.y) < 0.95 else -global_transform.basis.z
	_hand.global_transform = Transform3D(Basis.looking_at(forward, hand_up), w.lerp(joints[Humanoid.index_of(&"hand_r")], 0.5))


## The bucket trundles along behind his left shoulder. When he snaps he leaves it where it is.
func _roll_bucket() -> void:
	if hostile and _bucket_at.is_finite():
		return
	var wish: Vector3 = global_position + global_transform.basis.z * 0.85 - global_transform.basis.x * 0.55
	wish.y = global_position.y
	_bucket_at = wish if not _bucket_at.is_finite() else _bucket_at.lerp(wish, 0.12)
	var heading: Vector3 = wish - _bucket_at
	var turn: float = atan2(-heading.x, -heading.z) if heading.length() > 0.02 else _bucket.rotation.y
	_bucket.global_transform = Transform3D(Basis(Vector3.UP, lerp_angle(_bucket.rotation.y, turn, 0.2)), _bucket_at)


# ------------------------------------------------------------------ getting hurt

## Nothing hurts him. Shoot him, hit him, blow him up: he stops what he is doing, turns on
## whoever did it, shakes his fist and wants to know WHY. He does not attack for it, however
## often it happens. Only the fifth spill does that. If he is already after the player, a hit
## does at least stop him in his tracks for a moment.

func on_bullet_hit(bullet: Node, point: Vector3, normal: Vector3) -> bool:
	var who: Variant = bullet.get(&"shooter") if bullet != null else null
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 3, Mats.overalls(), Vector3.ONE * 0.02, normal * 2.0, 0.03)
	_outraged(who as Node3D if who is Node3D and is_instance_valid(who) else null, -normal)
	return false


func on_thrown_hit(item: Pickup) -> void:
	var who: Node = item.thrower if is_instance_valid(item.thrower) else null
	_outraged(who as Node3D, item.velocity.normalized())


func on_punched(by: Node, _at: Vector3) -> void:
	_outraged(by as Node3D, Vector3.ZERO)


func on_laser(direction: Vector3) -> void:
	_outraged(_player(), direction)


func on_explosion(centre: Vector3) -> void:
	_outraged(null, (global_position - centre).normalized())
	_stagger = 1.5


func _outraged(who: Node3D, came_from: Vector3) -> void:
	_why_left = 1.1
	_why_at = who.global_position if who != null else global_position - came_from * 3.0
	if hostile:
		_stagger = maxf(_stagger, 1.2)
	var now: int = Time.get_ticks_msec()
	if now - _last_why >= 1500:
		_last_why = now
		say(&"cleaner_why")
	outraged.emit(who)


func display_name() -> String:
	return "THE CLEANER"
