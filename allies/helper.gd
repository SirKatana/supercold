class_name Helper
extends CharacterBody3D
## The hired help: a red humanoid with a rifle who follows the player and shoots pink dudes.
## Bullets stop on him without hurting him, so he is also moving cover. He never shoots
## through the player. He runs on world time like everything else, but his contract is
## counted in real seconds by Game.

signal left

const T: Tuning = preload("res://data/tuning.tres")
const LAYER_ALLIES: int = 256

var skin: Humanoid
var joints: PackedVector3Array = []
var gun: Rifle
var agent: NavigationAgent3D
var target: PinkDude = null
var kills: int = 0
var leaving: bool = false
var voice: HelperVoice

## Line ids from allies/voice_lines.json. Each has a recorded clip.
const HIT_LINES: Array[StringName] = [&"hit_1", &"hit_2", &"hit_3", &"hit_4", &"hit_5", &"hit_6", &"hit_7"]
const KILL_LINES: Array[StringName] = [&"kill_1", &"kill_2", &"kill_3", &"kill_4", &"kill_5"]
const BLOCKED_LINES: Array[StringName] = [&"blocked_1", &"blocked_2", &"blocked_3"]
const QUIET_LINES: Array[StringName] = [&"quiet_1", &"quiet_2", &"quiet_3"]


static func pick(ids: Array[StringName]) -> StringName:
	return ids[randi() % ids.size()]

var _called_out: Dictionary[int, bool] = {}
var _hit_line_cooldown: float = 0.0
var _blocked_cooldown: float = 0.0
var _quiet_clock: float = 0.0
var _said_minute: bool = false
var _said_ten: bool = false
var _warned_barrels: Dictionary[int, bool] = {}

var _hand: Node3D
var _walk_phase: float = 0.0
var _aim: float = 0.0
var _aim_clock: float = 0.0
var _cooldown: float = 0.0
var _retarget: float = 0.0
var _repath: float = 0.0
var _desired: Vector3 = Vector3.ZERO
var _leave_clock: float = -1.0
var _flinch: float = 0.0


func _ready() -> void:
	add_to_group(&"allies")
	collision_layer = LAYER_ALLIES
	collision_mask = 1 | 32
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 1.0
	agent.avoidance_enabled = false
	add_child(agent)

	skin = Humanoid.create(self, Mats.helper_red())
	_hand = Node3D.new()
	_hand.top_level = true
	add_child(_hand)
	gun = Rifle.create()
	gun.attach_to(_hand)
	voice = HelperVoice.new()
	voice.name = "Voice"
	add_child(voice)
	Game.enemy_killed.connect(_on_enemy_killed)
	_pose(0.0)


## Said once, when he steps out of the capsule.
func greet() -> void:
	voice.say_line(&"greet", HelperVoice.Priority.IMPORTANT)


## Said when he rides the lift back up with the player after a death.
func greet_again() -> void:
	voice.say_line(&"greet_again", HelperVoice.Priority.IMPORTANT)


func _on_enemy_killed(_remaining: int) -> void:
	if target != null and (not is_instance_valid(target) or not target.alive):
		kills += 1
		target = null
		var kill_id: StringName = pick(KILL_LINES) if kills < 3 else (StringName("count_%d" % kills) if kills <= 12 else &"count_many")
		voice.say_line(kill_id, HelperVoice.Priority.CHATTER)


## His bullets pass through the player he works for.
func bullet_excludes() -> Array[RID]:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	return [player.get_rid()] if player != null else []


## Rounds stop on him and do nothing.
func on_bullet_hit(_bullet: Node, point: Vector3, normal: Vector3) -> bool:
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 3, Mats.helper_red(), Vector3.ONE * 0.02, normal * 1.5, 0.04)
	_flinch = 1.0
	if _hit_line_cooldown <= 0.0 and not leaving:
		_hit_line_cooldown = 2.5
		voice.say_line(pick(HIT_LINES), HelperVoice.Priority.CALLOUT)
	return false


func chest() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func muzzle() -> Vector3:
	return global_position + Vector3(0, 1.4, 0) - global_transform.basis.z.normalized() * 0.6


## Where to put the bullet: the chest, led by how far the dude will move, or for a shield
## trooper the glass slit, because nothing else works on him.
func aim_point(dude: PinkDude) -> Vector3:
	if dude is ShieldDude and (dude as ShieldDude).shield != null and is_instance_valid((dude as ShieldDude).shield):
		return (dude as ShieldDude).shield.global_transform * Vector3(0, Shield.VISOR_Y, -0.07)
	var at: Vector3 = dude.global_position + Vector3(0, 1.15 * dude.body_scale, 0)
	var flight: float = at.distance_to(muzzle()) / T.bullet_speed
	return at + dude.desired_velocity * flight * 0.8


func _pick_target() -> PinkDude:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var best: PinkDude = null
	var best_dist: float = T.helper_sight
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude == null or not dude.alive:
			continue
		var d: float = dude.global_position.distance_to(global_position)
		if d < best_dist and Sight.is_clear(space, chest(), dude.global_position + Vector3(0, 1.2, 0)):
			best_dist = d
			best = dude
	return best


## Never fire with the player anywhere near the line.
func _player_in_the_way(from: Vector3, to: Vector3) -> bool:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return false
	var line: Vector3 = to - from
	var along: float = clampf((player.chest_position() - from).dot(line) / maxf(line.length_squared(), 0.001), 0.0, 1.0)
	return (from + line * along).distance_to(player.chest_position()) < 0.9


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	if _leave_clock >= 0.0:
		_leave_clock -= delta
		_desired = Vector3.ZERO
		_aim = move_toward(_aim, 0.0, delta * 4.0)
		_pose(wd)
		if _leave_clock < 0.0:
			_vanish()
		return

	_cooldown = maxf(0.0, _cooldown - wd)
	_hit_line_cooldown = maxf(0.0, _hit_line_cooldown - delta)
	_blocked_cooldown = maxf(0.0, _blocked_cooldown - delta)
	_flinch = move_toward(_flinch, 0.0, delta * 3.0)
	_talk_about_the_clock()
	_retarget -= wd
	if _retarget <= 0.0 or target == null or not is_instance_valid(target) or not target.alive:
		_retarget = 0.25
		target = _pick_target()
		_call_out(target)

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if target != null:
		var at: Vector3 = aim_point(target)
		_face(at, wd)
		_desired = Vector3.ZERO
		_aim = move_toward(_aim, 1.0, wd * 6.0)
		_aim_clock += wd
		var facing: float = (-global_transform.basis.z).dot(((at - global_position) * Vector3(1, 0, 1)).normalized())
		var blocked: bool = _player_in_the_way(muzzle(), at)
		if blocked and _blocked_cooldown <= 0.0 and _aim_clock >= T.helper_aim_time:
			_blocked_cooldown = 7.0
			voice.say_line(pick(BLOCKED_LINES), HelperVoice.Priority.CALLOUT)
		_quiet_clock = 0.0
		if _aim_clock >= T.helper_aim_time and _cooldown <= 0.0 and facing > 0.97 and not blocked:
			gun.cooldown_left = 0.0
			gun.fire(muzzle(), (at - muzzle()).normalized(), self, false)
			_cooldown = T.helper_cadence
	else:
		_aim_clock = 0.0
		_aim = move_toward(_aim, 0.42, wd * 4.0)      # rifle at the low ready
		_follow(player, wd)
		_quiet_clock += delta
		if _quiet_clock > 9.0 and Game.alive_enemies > 0:
			_quiet_clock = -12.0
			voice.say_line(pick(QUIET_LINES), HelperVoice.Priority.CHATTER)

	var rate: float = wd / delta if delta > 0.0 else 0.0
	velocity.x = _desired.x * rate
	velocity.z = _desired.z * rate
	velocity.y = 0.0 if is_on_floor() else -4.0 * rate
	move_and_slide()
	_pose(wd)


func _follow(player: Player, wd: float) -> void:
	if player == null or global_position.distance_to(player.global_position) <= T.helper_follow_distance:
		_desired = Vector3.ZERO
		return
	_repath -= wd
	if _repath <= 0.0:
		_repath = 0.3
		agent.target_position = player.global_position
	if agent.is_navigation_finished():
		_desired = Vector3.ZERO
		return
	var next: Vector3 = agent.get_next_path_position()
	var flat := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if flat.length() < 0.05:
		_desired = Vector3.ZERO
		return
	_desired = flat.normalized() * T.helper_speed
	_face(global_position + flat, wd)


func _face(point: Vector3, wd: float) -> void:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, 11.0 * wd))


func _pose(wd: float) -> void:
	var moving: float = clampf(_desired.length() / T.helper_speed, 0.0, 1.0)
	_walk_phase += wd * 9.0 * moving
	# Leaving: one arm up, a wave goodbye.
	var left_arm: float = _aim if _leave_clock < 0.0 else 0.0
	var right_arm: float = _aim if _leave_clock < 0.0 else 1.15 + sin(Time.get_ticks_msec() / 110.0) * 0.12
	joints = Humanoid.to_world(Humanoid.pose(_walk_phase, moving, right_arm, left_arm, _flinch * 0.6), global_transform, 1.0)
	skin.apply(joints)
	var wrist: Vector3 = joints[Humanoid.index_of(&"wrist_r")]
	var forward: Vector3 = (wrist - joints[Humanoid.index_of(&"elbow_r")]).normalized()
	var up: Vector3 = Vector3.UP if absf(forward.y) < 0.95 else -global_transform.basis.z
	_hand.global_transform = Transform3D(Basis.looking_at(forward, up), wrist.lerp(joints[Humanoid.index_of(&"hand_r")], 0.5))


## Shouts where a newly spotted dude is, from the player's point of view. Once per dude.
func _call_out(dude: PinkDude) -> void:
	if dude == null or _called_out.has(dude.get_instance_id()):
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	if voice.say(HelperVoice.callout(player.global_transform, dude, Game.data), HelperVoice.Priority.CALLOUT,
			HelperVoice.callout_clips(player.global_transform, dude)):
		_called_out[dude.get_instance_id()] = true
		return
	_tip_about_barrels(dude)


## A dude standing next to a red barrel is an invitation.
func _tip_about_barrels(dude: PinkDude) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"barrels"):
		var barrel: GasBarrel = node as GasBarrel
		if barrel == null or _warned_barrels.has(barrel.get_instance_id()):
			continue
		if barrel.global_position.distance_to(dude.global_position) < T.barrel_radius * 0.7:
			if voice.say_line(&"barrel_tip", HelperVoice.Priority.CHATTER):
				_warned_barrels[barrel.get_instance_id()] = true
			return


func _talk_about_the_clock() -> void:
	var left: float = Game.helper_time_left
	if not _said_minute and left <= 60.0 and left > 50.0:
		_said_minute = true
		voice.say_line(&"minute_left", HelperVoice.Priority.IMPORTANT)
	elif not _said_ten and left <= 10.0 and left > 0.0:
		_said_ten = true
		voice.say_line(&"ten_seconds", HelperVoice.Priority.IMPORTANT)


## Contract over. He lowers the rifle, says goodbye, waves, and bursts into red shards.
func leave(floor_cleared: bool = false) -> void:
	if leaving:
		return
	leaving = true
	voice.say_line(&"bye_clear" if floor_cleared else &"bye_time", HelperVoice.Priority.IMPORTANT)
	target = null
	gun.visible = false
	_leave_clock = 2.4      # long enough to hear the goodbye


func _vanish() -> void:
	for joint: StringName in [&"head", &"chest", &"pelvis", &"knee_l", &"knee_r"]:
		Shatter.burst(Game.entities_root(self), joints[Humanoid.index_of(joint)], 5, Mats.helper_red(),
			Vector3.ONE * 0.12, Vector3.UP, 0.15)
	Sfx.play(&"shatter", global_position)
	left.emit()
	queue_free()
