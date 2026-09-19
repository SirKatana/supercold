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
var _fist: MeshInstance3D


func _ready() -> void:
	_hold_point = Node3D.new()
	_hold_point.name = "HoldPoint"
	_hold_point.position = Vector3(0.26, -0.2, -0.5)
	add_child(_hold_point)

	_fist = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.16)
	mesh.material = Mats.black()
	_fist.mesh = mesh
	_fist.position = Vector3(0.22, -0.28, -0.25)
	_fist.visible = false
	add_child(_fist)


func _physics_process(delta: float) -> void:
	punch_cooldown_left = maxf(0.0, punch_cooldown_left - TimeManager.world_delta(delta))
	if held != null and not is_instance_valid(held):
		_set_held(null)
	if player == null or not player.alive or not player.input_enabled:
		return
	if Input.is_action_just_pressed(&"primary"):
		primary()
	if Input.is_action_just_pressed(&"secondary"):
		secondary()
	if Input.is_action_just_pressed(&"interact"):
		interact()


func primary() -> void:
	if held is Pistol:
		var pistol: Pistol = held
		if pistol.fire(player.aim_origin() + player.aim_direction() * 0.35, player.aim_direction(), player):
			TimeManager.burst(T.burst_action)
			_kick()
	elif held != null:
		throw_held()
	else:
		punch()


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


func punch() -> bool:
	if punch_cooldown_left > 0.0:
		return false
	punch_cooldown_left = T.punch_cooldown
	TimeManager.burst(T.burst_action)
	Sfx.play(&"punch")
	_animate_fist()
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
	item.throw_from(player.aim_origin() + dir * 0.45, dir * T.throw_speed + Vector3.UP * 0.8, player)
	TimeManager.burst(T.burst_action)
	Sfx.play(&"throw")


func pick_up(item: Pickup) -> bool:
	if item == null or held != null or not item.is_available():
		return false
	item.attach_to(_hold_point)
	_set_held(item)
	TimeManager.burst(T.burst_pickup)
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
		if item == null or not item.is_available():
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
	if held is Pistol and is_instance_valid(held):
		var old: Pistol = held
		if old.ammo_changed.is_connected(_on_ammo_changed):
			old.ammo_changed.disconnect(_on_ammo_changed)
	held = item
	held_changed.emit(item)
	if item is Pistol:
		var pistol: Pistol = item
		pistol.ammo_changed.connect(_on_ammo_changed)
		ammo_changed.emit(pistol.ammo, T.pistol_ammo)
	else:
		ammo_changed.emit(-1, T.pistol_ammo)


func _on_ammo_changed(ammo: int) -> void:
	ammo_changed.emit(ammo, T.pistol_ammo)


func _kick() -> void:
	var tween: Tween = create_tween()
	_hold_point.rotation.x = 0.22
	_hold_point.position.z = -0.44
	tween.tween_property(_hold_point, ^"rotation:x", 0.0, 0.16)
	tween.parallel().tween_property(_hold_point, ^"position:z", -0.5, 0.16)


func _animate_fist() -> void:
	_fist.visible = true
	_fist.position = Vector3(0.22, -0.28, -0.25)
	var tween: Tween = create_tween()
	tween.tween_property(_fist, ^"position", Vector3(0.06, -0.12, -0.75), 0.07)
	tween.tween_property(_fist, ^"position", Vector3(0.22, -0.28, -0.25), 0.14)
	tween.tween_callback(func() -> void: _fist.visible = false)
