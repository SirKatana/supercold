class_name Hands
extends Node3D
## What the player holds and does with it: punch, pick up, shoot, throw.

signal held_changed(item: Pickup)
signal ammo_changed(ammo: int, capacity: int)
signal punched(target: Object)

const T: Tuning = preload("res://data/tuning.tres")
const PUNCH_MASK: int = 1 | 4 | 32

var player: Player
var held: Pickup = null
var punch_cooldown_left: float = 0.0

var _hold_point: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _punch_left_next: bool = false
var _arm_tween: Tween

# Far enough forward that the arms are inside the view frustum at all: this close to the
# lens, a hand a few centimetres lower than the eye is already off the bottom of the screen,
# and what is left of the forearm fills half the picture.
const ARM_REST_R := Vector3(0.30, -0.35, -0.54)
## Holding: the fist is under the crosshair line, not out to the side of it, and the weapon
# sits on top of it.
const ARM_HOLD_R := Vector3(0.17, -0.30, -0.47)
const ARM_REST_L := Vector3(-0.30, -0.35, -0.54)
## The off hand on the fore-end of a long gun: forward, inboard, and under the barrel.
const ARM_SUPPORT_L := Vector3(-0.11, -0.37, -0.74)
## How far the forearms pitch: the elbow drops away toward the bottom of the screen and the
## hand comes up to the gun.
const ARM_PITCH: float = 0.46
## Where a held weapon sits, in the Hands node's own space: right of the crosshair, below it,
## and far enough forward to clear the lens. The fist is placed under this, not the other way
## round, so nothing the arm does can roll the gun.
const GRIP := Vector3(0.17, -0.20, -0.62)
## A rifle is a metre long and the hand holds it near the back, so held at the same spot as a
## pistol its butt ends up inside the camera. Long guns are pushed forward by this much.
const LONG_GUN_PUSH: float = 0.26

var _supporting: bool = false


func _ready() -> void:
	_arm_r = _build_arm(ARM_REST_R, -1.0)
	_arm_l = _build_arm(ARM_REST_L, 1.0)
	# The grip hangs off the Hands node, NOT off the arm. Parented to the arm it inherited the
	# arm's pitch and yaw, which rolled every weapon onto its side and swung the magazine out
	# into the middle of the screen.
	_hold_point = Node3D.new()
	_hold_point.name = "HoldPoint"
	_hold_point.position = GRIP
	add_child(_hold_point)


## A forearm and a closed fist, built out of round parts and merged into one mesh. Boxes read
## as planks this close to the lens; a tapered tube with knuckles on it reads as an arm.
## `inward` is -1 for the right arm and +1 for the left.
func _build_arm(rest: Vector3, inward: float) -> Node3D:
	var arm := Node3D.new()
	arm.position = rest
	arm.rotation = Vector3(ARM_PITCH, 0.10 * inward, 0.0)
	add_child(arm)
	var mi := MeshInstance3D.new()
	var side: float = inward
	mi.mesh = MeshKit.cached(&"viewmodel_arm_r" if inward < 0.0 else &"viewmodel_arm_l",
		func(kit: MeshKit) -> void: _model_arm(kit, side))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm.add_child(mi)
	return arm


## -Z is the way the hand points. Sleeve, forearm, wrist, fist, fingers, thumb.
static func _model_arm(kit: MeshKit, inward: float) -> void:
	var skin: Material = Mats.arm()
	var cuff: Material = Mats.arm_cuff()
	# Sleeve, then the forearm tapering toward the wrist.
	kit.tube(0.052, 0.058, 0.13, Vector3(0, -0.005, 0.235), cuff, true, 10)
	kit.tube(0.043, 0.052, 0.24, Vector3(0, -0.004, 0.055), skin, true, 10)
	kit.ball(0.042, Vector3(0, -0.002, -0.068), skin, Vector3(1.0, 0.85, 1.0))        # wrist
	# The fist: a block of hand with four knuckles on top and the fingers curled under it.
	kit.box(Vector3(0.082, 0.062, 0.105), Vector3(0, 0.0, -0.132), skin)
	for i: int in 4:
		var across: float = (-0.028 + i * 0.019) * -inward
		var knuckle: float = 0.019 - absf(float(i) - 1.5) * 0.0015
		kit.ball(knuckle, Vector3(across, 0.028, -0.172), skin, Vector3(1.0, 0.9, 1.1))
		# Middle joint in front, fingertip tucked back under the palm.
		kit.tube(knuckle * 0.92, knuckle, 0.052, Vector3(across, 0.012, -0.200), skin, true, 8,
			Vector3(0.75, 0, 0))
		kit.tube(knuckle * 0.85, knuckle * 0.92, 0.040, Vector3(across, -0.030, -0.196), skin, true, 8,
			Vector3(2.0, 0, 0))
	# Thumb, lying along the top of whatever is being gripped.
	kit.tube(0.020, 0.023, 0.072, Vector3(0.036 * -inward, 0.020, -0.168), skin, true, 8,
		Vector3(0.25, -0.55 * inward, 0))
	kit.ball(0.020, Vector3(0.050 * -inward, 0.026, -0.200), skin)


func _physics_process(delta: float) -> void:
	punch_cooldown_left = maxf(0.0, punch_cooldown_left - TimeManager.world_delta(delta))
	if held != null and not is_instance_valid(held):
		_set_held(null)
	if player == null or not player.alive or not player.input_enabled:
		return
	if Input.is_action_just_pressed(&"primary"):
		primary()
	elif Input.is_action_pressed(&"primary") and is_instance_valid(held) and held is Gun and (held as Gun).automatic:
		primary()      # hold the trigger on an automatic
	if Input.is_action_just_pressed(&"secondary"):
		secondary()
	if Input.is_action_just_pressed(&"throw_item"):
		throw_held()
	# Hold right click to look down a scope.
	# A ram or a thrown gun may have been freed by the input handled just above.
	var can_scope: bool = is_instance_valid(held) and held is Gun and (held as Gun).has_scope
	player.fx.scope_wanted = can_scope and Input.is_action_pressed(&"secondary")
	visible = player.fx.scope_amount < 0.55 and player.alive
	if Input.is_action_just_pressed(&"interact"):
		interact()
	if Input.is_action_just_pressed(&"use_shield"):
		toggle_shield()


func primary() -> void:
	if held is Gun and not _may_fire_from_here():
		Sfx.play(&"door_hit")      # a dull knock: there is no room to bring it up in here
		return
	if held is Gun:
		var gun: Gun = held
		var shot: Array[Vector3] = _shot_from_muzzle(gun)
		if gun.fire(shot[0], shot[1], player):
			if gun.contraband and Game.guard != null and is_instance_valid(Game.guard):
				Game.guard._open_fire()      # you do not fire a weapon you were told to hand over
			TimeManager.burst(T.burst_action, gun.burst_strength)
			player.fx.kick(gun.kick)
			_kick()
	elif held is WaterBucket:
		if (held as WaterBucket).pour(player):
			TimeManager.burst(T.burst_action, T.burst_strength_throw)
			_animate_thrust()
		else:
			throw_held()      # empty: it is just a bucket now
	elif held is Spear:
		if (held as Spear).thrust(player):
			TimeManager.burst(T.burst_action, T.burst_strength_punch)
			_animate_thrust()
	elif held is Knife:
		if (held as Knife).stab(player):
			TimeManager.burst(T.burst_action, T.burst_strength_punch)
			_animate_thrust()
	elif held is Ram:
		if (held as Ram).bash(player):
			TimeManager.burst(T.burst_action, T.burst_strength_punch)
			_animate_thrust()
	elif held != null:
		throw_held()
	else:
		punch()


## The bullet leaves the gun, not the eye, and flies to whatever the crosshair is on.
## Seen from the side it reads as a tracer; fired from the eye it was a square blocking the target.
func _shot_from_muzzle(pistol: Gun) -> Array[Vector3]:
	var eye: Vector3 = player.aim_origin()
	var forward: Vector3 = player.aim_direction()
	if player.fx.scope_amount > 0.5:
		return [eye + forward * 0.6, forward]      # scoped: dead on the reticle
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var aim_query := PhysicsRayQueryParameters3D.create(eye, eye + forward * 120.0, 1 | 4 | 32)
	aim_query.exclude = [player.get_rid()]
	var aim_hit: Dictionary = space.intersect_ray(aim_query)
	var aim_point: Vector3 = aim_hit["position"] if not aim_hit.is_empty() else eye + forward * 120.0
	var muzzle: Vector3 = pistol.muzzle_position()
	# Hugging a wall can put the muzzle inside it. Fall back to the eye then.
	var clear_query := PhysicsRayQueryParameters3D.create(eye, muzzle, 1 | 32)
	if not space.intersect_ray(clear_query).is_empty() or aim_point.distance_to(eye) < 1.2:
		return [eye + forward * 0.35, forward]
	return [muzzle, (aim_point - muzzle).normalized()]


func secondary() -> void:
	if held is Gun and (held as Gun).has_scope:
		return      # right click is the scope on this one. Q throws it.
	if held != null:
		throw_held()
	else:
		pick_up(find_target())


func interact() -> void:
	var target: Pickup = find_target()
	if target == null:
		# Nothing to pick up: take a grate off, or climb into the duct behind one.
		if not _pull_off_a_grate():
			player.use_a_duct()
		return
	if held != null:
		held.drop(player.aim_origin() + player.aim_direction() * 0.4)
		_set_held(null)
	pick_up(target)


## E with nothing to pick up: if a vent grate is in reach, take hold of it and pull it off.
## Punching one works too; this is for the player who walks up to it and presses use.
## In a duct there is no shooting out into the room: you are flat on your face in a metal
## tube, and picking people off through a grate would be no contest. The only thing you can
## fire at down there is whatever is in the tube with you.
func _may_fire_from_here() -> bool:
	if not player.crawling or not VentDuct.inside(Game.data, player.global_position):
		return true
	var from: Vector3 = player.aim_origin()
	var query := PhysicsRayQueryParameters3D.create(from, from + player.aim_direction() * 12.0, 1 | 4 | 32)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit["collider"]
	if collider is VentLurker:
		return true
	# Somebody else who has got in here counts too. A duct wall does not.
	return collider is PinkDude and VentDuct.inside(Game.data, (collider as Node3D).global_position)


## Returns true if a grate came off.
func _pull_off_a_grate() -> bool:
	var origin: Vector3 = player.aim_origin()
	var forward: Vector3 = player.aim_direction()
	var best: VentGrate = null
	var best_distance: float = T.pickup_range + 0.6
	for node: Node in get_tree().get_nodes_in_group(&"grates"):
		var grate: VentGrate = node as VentGrate
		if grate == null or grate.is_broken:
			continue
		var to_grate: Vector3 = grate.global_position + Vector3(0, VentDuct.HEIGHT * 0.5, 0) - origin
		var distance: float = to_grate.length()
		if distance > best_distance or distance < 0.01:
			continue
		if forward.dot(to_grate / distance) < 0.55:
			continue      # it has to be roughly what you are looking at
		best = grate
		best_distance = distance
	if best == null:
		return false
	best.take_damage(99, -forward)      # it comes away in one go when you use your hands
	Sfx.play(&"door_break", best.global_position)
	TimeManager.burst(T.burst_action, T.burst_strength_break)
	_animate_thrust()
	return true


## F: take the nearest shield off the floor and wear it, or drop the one being worn.
func toggle_shield() -> bool:
	if player.shield != null and is_instance_valid(player.shield):
		player.shield.release_to_floor(player.global_position - player.global_transform.basis.z * 0.9)
		player.shield = null
		_pose_support_arm(_supporting)
		return true
	var found: Shield = nearest_shield()
	if found == null:
		return false
	found.wear(player.head)
	player.shield = found
	_arm_l.visible = false      # that arm is behind the shield now
	TimeManager.burst(T.burst_pickup, T.burst_strength_pickup)
	return true


func nearest_shield() -> Shield:
	var best: Shield = null
	var best_dist: float = T.shield_pickup_range
	for node: Node in get_tree().get_nodes_in_group(&"shields"):
		var s: Shield = node as Shield
		if s == null or s.state != Pickup.State.RESTING:
			continue
		var d: float = s.grab_point().distance_to(player.global_position + Vector3.UP * 0.5)
		if d < best_dist:
			best_dist = d
			best = s
	return best


func punch() -> bool:
	if punch_cooldown_left > 0.0:
		return false
	punch_cooldown_left = T.punch_cooldown
	TimeManager.burst(T.burst_action, T.burst_strength_punch)
	Sfx.play(&"punch")
	_animate_jab()
	var from: Vector3 = player.aim_origin()
	var query := PhysicsRayQueryParameters3D.create(from, from + player.aim_direction() * T.punch_range, PUNCH_MASK)
	query.exclude = [player.get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Object = result["collider"]
	if collider.has_method(&"on_punched"):
		collider.call(&"on_punched", player, result["position"])
	punched.emit(collider)
	return true


func throw_held() -> void:
	if held == null:
		return
	var item: Pickup = held
	_set_held(null)
	var dir: Vector3 = player.aim_direction()
	item.throw_from(player.aim_origin() + dir * 0.45, dir * T.throw_speed * item.throw_speed_scale + Vector3.UP * 0.8, player)
	TimeManager.burst(T.burst_action, T.burst_strength_throw)
	Sfx.play(&"throw")


func pick_up(item: Pickup) -> bool:
	if item == null or held != null or not item.is_available():
		return false
	item.attach_to(_hold_point)
	_set_held(item)
	TimeManager.burst(T.burst_pickup, T.burst_strength_pickup)
	Sfx.play(&"pickup")
	return true


## Best available pickup inside the reach cone, with a clear line to it.
func find_target() -> Pickup:
	var origin: Vector3 = player.aim_origin()
	var forward: Vector3 = player.aim_direction()
	var best: Pickup = null
	var best_score: float = -INF
	var cos_limit: float = cos(deg_to_rad(T.pickup_cone_deg))
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		var item: Pickup = node as Pickup
		if item == null or not item.is_available() or item is Shield:
			continue
		var to_item: Vector3 = item.global_position - origin
		var distance: float = to_item.length()
		if distance > T.pickup_range or distance < 0.01:
			continue
		var alignment: float = forward.dot(to_item / distance)
		# Things at your feet are always in reach, even outside the cone.
		if alignment < cos_limit and distance > 1.0:
			continue
		if alignment < 0.5:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, item.global_position, 1 | 32)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var score: float = alignment * 4.0 - distance * 0.2
		if score > best_score:
			best_score = score
			best = item
	return best


func _set_held(item: Pickup) -> void:
	if held is Gun and is_instance_valid(held):
		var old: Gun = held
		if old.ammo_changed.is_connected(_on_ammo_changed):
			old.ammo_changed.disconnect(_on_ammo_changed)
	held = item
	held_changed.emit(item)
	_arm_r.position = ARM_HOLD_R if item != null else ARM_REST_R
	var long_gun: bool = item is Gun and (item as Gun).two_handed
	_hold_point.position = GRIP + (Vector3(0, 0, -LONG_GUN_PUSH) if long_gun else Vector3.ZERO)
	_pose_support_arm(item is Gun and (item as Gun).two_handed)
	if item is Gun:
		var pistol: Gun = item
		pistol.ammo_changed.connect(_on_ammo_changed)
		ammo_changed.emit(pistol.ammo, pistol.capacity)
	elif item is Ram:
		var ram: Ram = item
		# The pips show bashes left, same as rounds for a pistol.
		ram.durability_changed.connect(func(left: int) -> void: ammo_changed.emit(left, T.ram_hits))
		ammo_changed.emit(ram.durability, T.ram_hits)
	else:
		ammo_changed.emit(-1, T.pistol_ammo)


func _on_ammo_changed(ammo: int) -> void:
	ammo_changed.emit(ammo, (held as Gun).capacity if held is Gun else T.pistol_ammo)


## A long gun gets the off hand under its fore-end.
func _pose_support_arm(supporting: bool) -> void:
	_supporting = supporting
	# The off hand is on screen with empty hands or on a long gun's fore-end. With a pistol it
	# drops out of view: left up it lies across the picture like a plank.
	_arm_l.visible = player.shield == null and (supporting or held == null)
	if supporting:
		_arm_l.position = ARM_SUPPORT_L
		# Reaching forward and across to the fore-end, palm up under the barrel.
		_arm_l.rotation = Vector3(ARM_PITCH + 0.28, 0.34, -0.10)
	else:
		_arm_l.position = ARM_REST_L
		_arm_l.rotation = Vector3(ARM_PITCH, 0.10, 0.0)


## Where the grip rests for whatever is in the hand at the moment.
func _grip_home() -> Vector3:
	var long_gun: bool = held is Gun and (held as Gun).two_handed
	return GRIP + (Vector3(0, 0, -LONG_GUN_PUSH) if long_gun else Vector3.ZERO)


func _kick() -> void:
	var tween: Tween = create_tween()
	_arm_r.rotation.x = ARM_PITCH + 0.18
	_arm_r.position.z = ARM_HOLD_R.z + 0.05
	_hold_point.position = _grip_home() + Vector3(0, 0.012, 0.055)
	_hold_point.rotation.x = -0.10
	tween.tween_property(_arm_r, ^"rotation:x", ARM_PITCH, 0.16)
	tween.parallel().tween_property(_arm_r, ^"position:z", ARM_HOLD_R.z, 0.16)
	tween.parallel().tween_property(_hold_point, ^"position", _grip_home(), 0.16)
	tween.parallel().tween_property(_hold_point, ^"rotation:x", 0.0, 0.16)


## The ram goes straight out from the hip and back.
func _animate_thrust() -> void:
	if _arm_tween != null and _arm_tween.is_valid():
		_arm_tween.kill()
	_arm_r.position = ARM_HOLD_R
	_arm_tween = create_tween()
	_arm_tween.tween_property(_arm_r, ^"position", ARM_HOLD_R + Vector3(-0.10, 0.06, -0.42), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arm_tween.parallel().tween_property(_hold_point, ^"position", _grip_home() + Vector3(-0.10, 0.06, -0.42), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arm_tween.tween_property(_arm_r, ^"position", ARM_HOLD_R, 0.24).set_trans(Tween.TRANS_QUAD)
	_arm_tween.parallel().tween_property(_hold_point, ^"position", _grip_home(), 0.24).set_trans(Tween.TRANS_QUAD)


## A short jab from alternating sides that ends near the crosshair, then pulls back.
func _animate_jab() -> void:
	var arm: Node3D = _arm_l if _punch_left_next else _arm_r
	var rest: Vector3 = ARM_REST_L if _punch_left_next else ARM_REST_R
	var side: float = -1.0 if _punch_left_next else 1.0
	_punch_left_next = not _punch_left_next
	if _arm_tween != null and _arm_tween.is_valid():
		_arm_tween.kill()
		_arm_l.position = ARM_SUPPORT_L if _supporting else ARM_REST_L
		_arm_r.position = ARM_REST_R
	_arm_tween = create_tween()
	_arm_tween.tween_property(arm, ^"position", Vector3(0.11 * side, -0.20, -0.58), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arm_tween.tween_property(arm, ^"position", rest, 0.18).set_trans(Tween.TRANS_QUAD)
