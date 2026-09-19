class_name Ram
extends Pickup
## The wall breaker: a black steel cylinder with two carry handles. Bash with it to open
## doors and walls. It survives `ram_hits` bashes and then cracks in half. Throw it at a
## dude and it kills him, and cracks in half doing it.

signal durability_changed(left: int)
signal cracked

const LENGTH: float = 0.86
const RADIUS: float = 0.085

var durability: int = 5
var cooldown_left: float = 0.0


static func create() -> Ram:
	var r := Ram.new()
	r.kind = &"ram"
	r.name = "Ram"
	r.durability = T.ram_hits
	r.blunt_damage = T.ram_throw_damage
	r.hold_offset = Vector3(0.05, -0.13, -0.16)
	return r


func _build_mesh(root: Node3D) -> void:
	var body := Node3D.new()
	body.position = Vector3(0, 0.0, -0.12)
	root.add_child(body)
	_build_half(body, -1.0)
	_build_half(body, 1.0)


## Front (-1) or back (+1) half of the ram. The same pieces are reused for the broken halves.
static func _build_half(parent: Node3D, side: float) -> void:
	var tube := MeshInstance3D.new()
	var tube_mesh := CylinderMesh.new()
	tube_mesh.top_radius = RADIUS
	tube_mesh.bottom_radius = RADIUS
	tube_mesh.height = LENGTH * 0.5
	tube_mesh.radial_segments = 14
	tube_mesh.material = Mats.black()
	tube.mesh = tube_mesh
	tube.rotation.x = PI * 0.5
	tube.position.z = side * LENGTH * 0.25
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(tube)

	# Flared steel striking face at the front, a plain band at the back.
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = RADIUS * (1.22 if side < 0.0 else 1.08)
	cap_mesh.bottom_radius = cap_mesh.top_radius
	cap_mesh.height = 0.07 if side < 0.0 else 0.04
	cap_mesh.radial_segments = 14
	cap_mesh.material = Mats.gunmetal()
	cap.mesh = cap_mesh
	cap.rotation.x = PI * 0.5
	cap.position.z = side * (LENGTH * 0.5 - cap_mesh.height * 0.5)
	parent.add_child(cap)

	# Carry handle: two posts and a grip bar.
	var z: float = side * LENGTH * 0.22
	for post_z: float in [z - 0.08, z + 0.08]:
		_bar(parent, Vector3(0.022, 0.085, 0.022), Vector3(0, RADIUS + 0.04, post_z))
	_bar(parent, Vector3(0.028, 0.028, 0.20), Vector3(0, RADIUS + 0.085, z))


static func _bar(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Mats.polymer()
	mi.mesh = mesh
	mi.position = at
	parent.add_child(mi)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - TimeManager.world_delta(delta))
	super(delta)


func can_bash() -> bool:
	return durability > 0 and cooldown_left <= 0.0


## Swings the ram at whatever is in front of the player. Returns true if it swung.
func bash(player: Player) -> bool:
	if not can_bash():
		return false
	cooldown_left = T.ram_cooldown
	var from: Vector3 = player.aim_origin()
	var dir: Vector3 = player.aim_direction()
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * T.ram_range, 1 | 4 | 32)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	Sfx.play(&"punch")
	if hit.is_empty():
		return true
	var collider: Object = hit["collider"]
	var point: Vector3 = hit["position"]
	var landed: bool = false
	if collider is PinkDude:
		(collider as PinkDude).on_rammed(dir)
		landed = true
	elif collider is Door:
		(collider as Door).take_damage(99, dir, point)
		landed = true
	elif collider is GlassPane:
		(collider as GlassPane).take_damage(99, dir)
		landed = true
	elif collider is Node and (collider as Node).is_in_group(&"walls"):
		landed = WallBreach.bash(collider as StaticBody3D, point, hit["normal"], dir)
	elif collider.has_method(&"on_punched"):
		collider.call(&"on_punched", player, point)   # the lift button, for one
	if landed:
		_spend()
	return true


func _spend() -> void:
	durability -= 1
	durability_changed.emit(durability)
	if durability <= 0:
		crack_in_half(Vector3.ZERO)


func _on_flight_hit(collider: Object, point: Vector3, normal: Vector3) -> void:
	var hit_a_dude: bool = dangerous and collider is PinkDude
	var flying: Vector3 = velocity
	super(collider, point, normal)
	if hit_a_dude and not is_queued_for_deletion():
		crack_in_half(flying)


## Two halves fall apart where the ram was, with a few splinters. The pickup is gone.
func crack_in_half(carry: Vector3) -> void:
	if is_queued_for_deletion():
		return
	var world: Node = Game.entities_root(self)
	var here: Transform3D = global_transform
	for side: float in [-1.0, 1.0]:
		var half: Debris = Debris.spawn(world, here, carry * 0.25 + here.basis.z * side * 1.6 + Vector3.UP * 1.8)
		var holder := Node3D.new()
		holder.position = Vector3(0, 0, -0.12)
		half.add_child(holder)
		# Build one half, then slide it so the broken end sits at the debris origin.
		var piece := Node3D.new()
		piece.position.z = -side * LENGTH * 0.25
		holder.add_child(piece)
		_build_half(piece, side)
	Shatter.burst(world, global_position, 7, Mats.black(), Vector3.ONE * 0.05, carry * 0.1, 0.06)
	Sfx.play(&"door_break", global_position)
	cracked.emit()
	queue_free()
