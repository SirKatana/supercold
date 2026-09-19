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

const ARM_REST_R := Vector3(0.31, -0.43, -0.26)
const ARM_HOLD_R := Vector3(0.23, -0.25, -0.16)
const ARM_REST_L := Vector3(-0.31, -0.43, -0.26)
const ARM_SUPPORT_L := Vector3(0.05, -0.385, -0.30)

var _supporting: bool = false


func _ready() -> void:
	_arm_r = _build_arm(ARM_REST_R, -1.0)
	_arm_l = _build_arm(ARM_REST_L, 1.0)
	# Whatever is held sits in the right fist.
	_hold_point = Node3D.new()
	_hold_point.name = "HoldPoint"
	_hold_point.position = Vector3(0, 0.05, -0.30)
	_arm_r.add_child(_hold_point)


## A forearm and fist that reach in from a lower screen corner. `inward` is -1 for the
## right arm and +1 for the left, so both angle toward the crosshair.
func _build_arm(rest: Vector3, inward: float) -> Node3D:
	var arm := Node3D.new()
	arm.position = rest
	arm.rotation = Vector3(0.12, 0.10 * inward, 0.0)
	add_child(arm)
	_add_arm_box(arm, Vector3(0.078, 0.074, 0.30), Vector3(0, 0, 0.10))          # forearm
	_add_arm_box(arm, Vector3(0.066, 0.062, 0.10), Vector3(0, 0, -0.10))         # wrist, narrower
	_add_arm_box(arm, Vector3(0.092, 0.046, 0.095), Vector3(0, 0.012, -0.195))   # back of the hand
	for i: int in 4:                                                             # four curled fingers
		_add_arm_box(arm, Vector3(0.0205, 0.050, 0.050), Vector3(-0.0345 + i * 0.023, -0.016, -0.262))
		_add_arm_box(arm, Vector3(0.0205, 0.030, 0.030), Vector3(-0.0345 + i * 0.023, -0.040, -0.235))
	_add_arm_box(arm, Vector3(0.026, 0.030, 0.075), Vector3(0.052 * inward * -1.0, -0.006, -0.225))   # thumb
	return arm


func _add_arm_box(arm: Node3D, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Mats.arm()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm.add_child(mi)


func _physics_process(delta: float) -> void:
	punch_cooldown_left = maxf(0.0, punch_cooldown_left - TimeManager.world_delta(delta))
	if held != null and not is_instance_valid(held):
		_set_held(null)
	if player == null or not player.alive or not player.input_enabled:
		return
	if Input.is_action_just_pressed(&"primary"):
		primary()
	elif Input.is_action_pressed(&"primary") and held is Gun and (held as Gun).automatic:
		primary()      # hold the trigger on an automatic
	if Input.is_action_just_pressed(&"secondary"):
		secondary()
	if Input.is_action_just_pressed(&"interact"):
		interact()
	if Input.is_action_just_pressed(&"use_shield"):
		toggle_shield()


func primary() -> void:
	if held is Gun:
		var gun: Gun = held
		var shot: Array[Vector3] = _shot_from_muzzle(gun)
		if gun.fire(shot[0], shot[1], player):
			TimeManager.burst(T.burst_action, gun.burst_strength)
			player.fx.kick(gun.kick)
			_kick()
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
	if held != null:
		throw_held()
	else:
		pick_up(find_target())


func interact() -> void:
	var target: Pickup = find_target()
	if target == null:
		return
	if held != null:
		held.drop(player.aim_origin() + player.aim_direction() * 0.4)
		_set_held(null)
	pick_up(target)


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
	_arm_l.visible = player.shield == null
	if supporting:
		_arm_l.position = ARM_SUPPORT_L
		_arm_l.rotation = Vector3(0.36, -0.36, 0.0)
	else:
		_arm_l.position = ARM_REST_L
		_arm_l.rotation = Vector3(0.12, 0.10, 0.0)


func _kick() -> void:
	var tween: Tween = create_tween()
	_arm_r.rotation.x = 0.30
	_arm_r.position.z = ARM_HOLD_R.z + 0.05
	tween.tween_property(_arm_r, ^"rotation:x", 0.12, 0.16)
	tween.parallel().tween_property(_arm_r, ^"position:z", ARM_HOLD_R.z, 0.16)


## The ram goes straight out from the hip and back.
func _animate_thrust() -> void:
	if _arm_tween != null and _arm_tween.is_valid():
		_arm_tween.kill()
	_arm_r.position = ARM_HOLD_R
	_arm_tween = create_tween()
	_arm_tween.tween_property(_arm_r, ^"position", ARM_HOLD_R + Vector3(-0.10, 0.06, -0.42), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arm_tween.tween_property(_arm_r, ^"position", ARM_HOLD_R, 0.24).set_trans(Tween.TRANS_QUAD)


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
