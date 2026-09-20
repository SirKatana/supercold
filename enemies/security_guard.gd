class_name SecurityGuard
extends CharacterBody3D
## Building security, in a dark armoured suit and a peaked cap. He is not a pink dude and he does
## not count toward clearing the floor. He is posted outside the arrival lift only when the
## player rode up holding a weapon.
##
## He asks for it. Walk up to him, or drop it, and he takes it, says thank you, and walks into
## the lift you came out of. Walk past him still holding it, or fire it, and he shoots, and he
## does not stop until you drop it or you are dead. Nothing the player has can hurt him.

signal weapon_taken(kind: StringName)
signal opened_fire
signal left

enum Mode { WAITING, FIRING, LEAVING }

const T: Tuning = preload("res://data/tuning.tres")

var mode: Mode = Mode.WAITING
var skin: Humanoid
var joints: PackedVector3Array = []
var gun: Pistol
var voice: HelperVoice
var taken: int = 0

var _hand: Node3D
var _lift: Vector3
var _out: Vector3 = Vector3.FORWARD
var _post: Vector3
var _aim: float = 0.0
var _cooldown: float = 0.0
var _walk_phase: float = 0.0
var _moving: float = 0.0
var _cap: MeshInstance3D
var _vest: MeshInstance3D
var _warned: bool = false


func _ready() -> void:
	add_to_group(&"security")
	collision_layer = 256       # bullets stop on him, the player walks round him
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.85
	shape.shape = capsule
	shape.position.y = 0.925
	add_child(shape)

	skin = Humanoid.create(self, Mats.security_suit(), 1.04)
	skin.bulk = 1.12
	skin.set_sunglasses(true)
	_cap = _accessory(MeshKit.cached(&"guard_cap", _model_cap))
	_vest = _accessory(MeshKit.cached(&"guard_vest", _model_vest))
	var label := Label3D.new()
	label.text = "SECURITY"
	label.font_size = 30
	label.pixel_size = 0.0019
	label.modulate = Color(0.95, 0.95, 0.95)
	label.shaded = false
	label.position = Vector3(0, 0.005, -0.137)
	label.rotation.y = PI
	_vest.add_child(label)

	_hand = Node3D.new()
	_hand.top_level = true
	add_child(_hand)
	gun = Pistol.create()
	gun.attach_to(_hand)
	gun.bullet_speed_scale = T.guard_bullet_speed

	voice = HelperVoice.new()
	voice.name = "Voice"
	add_child(voice)
	_pose(0.0)


func _accessory(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Peaked cap: crown, band, badge and a stiff peak. Origin at the centre of the skull, -Z forward.
static func _model_cap(kit: MeshKit) -> void:
	var cloth: Material = Mats.security_suit()
	var shiny: Material = Mats.polymer()
	kit.tube(0.128, 0.118, 0.050, Vector3(0, 0.125, 0.004), cloth, false, 18)       # crown
	kit.tube(0.116, 0.116, 0.030, Vector3(0, 0.090, 0.004), shiny, false, 18)       # band
	kit.box(Vector3(0.150, 0.010, 0.085), Vector3(0, 0.078, -0.130), shiny, Vector3(0.22, 0, 0))   # peak
	kit.box(Vector3(0.034, 0.030, 0.008), Vector3(0, 0.104, -0.116), Mats.brass())                  # cap badge


## Armoured vest over the suit: front and back plates, shoulder straps, belt, pouches, radio, badge.
## Origin at the chest joint, Y up the spine, -Z forward.
static func _model_vest(kit: MeshKit) -> void:
	var plate: Material = Mats.polymer()
	var strap: Material = Mats.rubber()
	kit.box(Vector3(0.360, 0.330, 0.050), Vector3(0, 0.000, -0.108), plate)          # front plate
	kit.box(Vector3(0.360, 0.330, 0.050), Vector3(0, 0.000, 0.108), plate)           # back plate
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.060, 0.050, 0.260), Vector3(0.125 * side, 0.170, 0), strap)   # shoulder strap
		kit.box(Vector3(0.030, 0.300, 0.200), Vector3(0.188 * side, -0.010, 0), strap)  # side panel
		kit.box(Vector3(0.080, 0.090, 0.040), Vector3(0.100 * side, -0.100, -0.150), strap)   # pouch
	kit.box(Vector3(0.390, 0.045, 0.290), Vector3(0, -0.230, 0), strap)              # duty belt
	kit.box(Vector3(0.050, 0.035, 0.020), Vector3(0, -0.230, -0.150), Mats.steel())  # buckle
	kit.box(Vector3(0.045, 0.085, 0.030), Vector3(-0.120, 0.110, -0.140), plate)     # radio
	kit.tube(0.004, 0.004, 0.080, Vector3(-0.135, 0.190, -0.140), plate, false, 6)   # aerial
	kit.box(Vector3(0.040, 0.048, 0.006), Vector3(0.110, 0.100, -0.136), Mats.brass())   # badge


## Stand here, facing the lift at `lift`, which opens toward `out`.
func post(at: Vector3, lift: Vector3, out: Vector3) -> void:
	_post = at
	_lift = lift
	_out = out.normalized()
	global_position = at
	look_at(Vector3(lift.x, at.y, lift.z))
	_pose(0.0)


func player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func on_bullet_hit(_bullet: Node, point: Vector3, normal: Vector3) -> bool:
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 4, Mats.steel(), Vector3.ONE * 0.02, normal * 2.0, 0.035)
	Sfx.play(&"door_hit", point)
	_open_fire()      # shooting security is not moving on quietly
	return false


## The player's bullets pass nothing here. His pass his own suit.
func bullet_excludes() -> Array[RID]:
	return []


func muzzle() -> Vector3:
	return global_position + Vector3(0, 1.45, 0) - global_transform.basis.z.normalized() * 0.6 + global_transform.basis.x.normalized() * 0.18


## The weapon the player brought up, if he still has it in his hand.
func _contraband_in_hand(p: Player) -> Pickup:
	var held: Pickup = p.hands.held
	return held if held != null and is_instance_valid(held) and held.is_weapon() else null


## How far out of the lift the player has come, measured along the way the doors face.
func _progress(p: Player) -> float:
	return (p.global_position - _lift).dot(_out)


func _open_fire() -> void:
	if mode == Mode.WAITING:
		mode = Mode.FIRING
		_say_now(&"guard_stop")
		opened_fire.emit()


## Cuts off whatever he was saying. "Stop!" does not wait for the end of a polite sentence.
func _say_now(id: StringName) -> void:
	voice.shut_up()
	voice._current_priority = -1
	voice.say_line(id, HelperVoice.Priority.IMPORTANT)


func _take(item: Pickup) -> void:
	taken += 1
	weapon_taken.emit(item.kind)
	Sfx.play(&"pickup", global_position)
	item.queue_free()


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	_cooldown = maxf(0.0, _cooldown - wd)
	var p: Player = player()
	_moving = 0.0
	if p == null or not p.alive:
		_aim = move_toward(_aim, 0.0, wd * 4.0)
		_pose(wd)
		return

	if mode == Mode.LEAVING:
		_walk_to_lift(wd, delta)
		_pose(wd)
		return

	if not _warned and _progress(p) > 0.9:
		_warned = true
		voice.say_line(&"guard_halt", HelperVoice.Priority.IMPORTANT)

	# Anything he is owed that is lying about, he picks up.
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		var item: Pickup = node as Pickup
		if item != null and item.contraband and item.state != Pickup.State.HELD \
				and item.global_position.distance_to(global_position) <= T.guard_floor_reach:
			_take(item)

	var armed: Pickup = _contraband_in_hand(p)
	if armed != null and p.global_position.distance_to(global_position) <= T.guard_take_range and mode == Mode.WAITING:
		# Close enough to hand it over. He takes it out of the player's hand.
		p.hands.surrender()
		_take(armed)
		armed = null

	if armed == null and not _anything_still_owed():
		mode = Mode.LEAVING
		_say_now(&"guard_thanks" if taken > 0 else &"guard_clear")
		_pose(wd)
		return

	_face(p.global_position, wd)
	if mode == Mode.WAITING and armed != null and _progress(p) > _progress_of_post() + T.guard_line:
		_open_fire()      # he walked on with it
	if mode == Mode.FIRING:
		if armed == null:
			mode = Mode.WAITING      # it is on the floor now: that will do
		else:
			_aim = move_toward(_aim, 1.0, wd * 8.0)
			if _aim > 0.9 and _cooldown <= 0.0:
				_cooldown = T.guard_cadence
				var flight: float = muzzle().distance_to(p.chest_position()) / (T.bullet_speed * T.guard_bullet_speed)
				var at: Vector3 = p.chest_position() + p.get_real_velocity() * flight
				gun.cooldown_left = 0.0
				gun.fire(muzzle(), (at - muzzle()).normalized(), self, false)
	else:
		_aim = move_toward(_aim, 0.0, wd * 4.0)
	_pose(wd)


func _progress_of_post() -> float:
	return (_post - _lift).dot(_out)


func _anything_still_owed() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		var item: Pickup = node as Pickup
		if item != null and item.contraband and not item.is_queued_for_deletion():
			return true
	return false


## Job done. He walks into the lift the player came out of and is gone. Real time: he should
## not take a quarter of an hour because the player is standing still.
func _walk_to_lift(wd: float, delta: float) -> void:
	_aim = move_toward(_aim, 0.0, wd * 4.0)
	var flat := Vector3(_lift.x - global_position.x, 0, _lift.z - global_position.z)
	if flat.length() < 0.5:
		left.emit()
		queue_free()
		return
	_face(global_position + flat, delta)
	global_position += flat.normalized() * 2.6 * delta
	_moving = 0.7
	_walk_phase += delta * 8.0 * _moving


func _face(point: Vector3, step: float) -> void:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, 9.0 * step))


func _pose(_wd: float) -> void:
	# One hand out, palm up, while he waits for the weapon.
	var asking: float = 0.62 if mode == Mode.WAITING and _warned else 0.0
	joints = Humanoid.to_world(Humanoid.pose(_walk_phase, _moving, _aim, asking * (1.0 - _aim), 0.0, true), global_transform, 1.04)
	skin.apply(joints)
	_cap.global_transform = skin.shades_transform()
	var chest: Vector3 = joints[Humanoid.index_of(&"chest")]
	var up: Vector3 = (joints[Humanoid.index_of(&"neck")] - joints[Humanoid.index_of(&"spine")]).normalized()
	var across: Vector3 = (joints[Humanoid.index_of(&"shoulder_r")] - joints[Humanoid.index_of(&"shoulder_l")]).normalized()
	var back: Vector3 = across.cross(up).normalized()
	_vest.global_transform = Transform3D(Basis(across, up, back) * 1.04, chest)
	var wrist: Vector3 = joints[Humanoid.index_of(&"wrist_r")]
	var forward: Vector3 = (wrist - joints[Humanoid.index_of(&"elbow_r")]).normalized()
	var hand_up: Vector3 = Vector3.UP if absf(forward.y) < 0.95 else -global_transform.basis.z
	_hand.global_transform = Transform3D(Basis.looking_at(forward, hand_up), wrist.lerp(joints[Humanoid.index_of(&"hand_r")], 0.5))
