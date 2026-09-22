class_name Door
extends StaticBody3D
## Breakable door. The player smashes it; dudes just walk up and it swings open for them.
##
## A pair of wooden leaves in a steel frame with a glazed transom. Each leaf hangs on three
## hinges at its jamb, swings away from whoever is coming through, has a glass window, and is
## broken on its own: a hit breaks the leaf it lands on, and the doorway is clear once both
## are gone. A blast, the ram, or a hit on the seam between them takes both at once.

signal broken(door: Door)

const T: Tuning = preload("res://data/tuning.tres")
const HEIGHT: float = 2.6
const THICKNESS: float = 0.12
const JAMB: float = 0.07
const LEAF_HEIGHT: float = 2.18
const LEAF_THICKNESS: float = 0.045
const SWING: float = 1.62          # radians, a little past square
const WINDOW_SIZE := Vector2(0.16, 0.76)
const WINDOW_Y: float = 1.58
const WINDOW_FROM_EDGE: float = 0.20

var along_x: bool = true
var hp: int = 2
var open_amount: float = 0.0
var is_broken: bool = false

var leaf_hp: Array[int] = [0, 0]
var leaf_broken: Array[bool] = [false, false]
var _leaf_shapes: Array[CollisionShape3D] = []
var _visual: Node3D
var _frame: MeshInstance3D
var _leaves: Array[Node3D] = []
var _swing_sign: float = 1.0
var _sensor: Area3D


func _ready() -> void:
	add_to_group(&"doors")
	collision_layer = 32
	collision_mask = 0
	hp = T.door_hp
	leaf_hp = [T.door_hp, T.door_hp]
	var width: float = T.cell_size

	# Modelled along X and turned for a door in a north-south wall.
	_visual = Node3D.new()
	_visual.rotation.y = 0.0 if along_x else PI * 0.5
	add_child(_visual)
	# One solid half per leaf, together exactly the old single box.
	for side: float in [-1.0, 1.0]:
		var half := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width * 0.5, HEIGHT, THICKNESS)
		half.shape = box
		half.position = Vector3(side * width * 0.25, HEIGHT * 0.5, 0.0)
		half.rotation.y = _visual.rotation.y
		if not along_x:
			half.position = Vector3(0.0, HEIGHT * 0.5, -side * width * 0.25)
		add_child(half)
		_leaf_shapes.append(half)
	_frame = MeshInstance3D.new()
	_frame.name = "DoorFrame"
	_frame.mesh = MeshKit.cached(&"door_frame", _model_frame)
	_visual.add_child(_frame)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * (width * 0.5 - JAMB), 0.0, 0.0)
		hinge.rotation.y = 0.0 if side < 0.0 else PI
		_visual.add_child(hinge)
		var leaf := MeshInstance3D.new()
		leaf.mesh = MeshKit.cached(&"door_leaf", _model_leaf)
		hinge.add_child(leaf)
		_leaves.append(hinge)

	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 4 | 256      # dudes, and the helper and security
	var sensor_shape := CollisionShape3D.new()
	var sensor_box := BoxShape3D.new()
	sensor_box.size = Vector3(width, HEIGHT, 3.2) if along_x else Vector3(3.2, HEIGHT, width)
	sensor_shape.shape = sensor_box
	sensor_shape.position.y = HEIGHT * 0.5
	_sensor.add_child(sensor_shape)
	add_child(_sensor)


func is_open() -> bool:
	return open_amount > 0.5


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	var wanted: float = 1.0 if _sensor.has_overlapping_bodies() else 0.0
	if wanted > 0.5 and open_amount < 0.02:
		_swing_sign = _side_of_whoever_is_coming()
	open_amount = move_toward(open_amount, wanted, wd * 4.0)
	# Ease in and out, so the leaves start and land softly.
	var eased: float = open_amount * open_amount * (3.0 - 2.0 * open_amount)
	_leaves[0].rotation.y = _swing_sign * SWING * eased
	_leaves[1].rotation.y = PI - _swing_sign * SWING * eased
	for i: int in 2:
		_leaf_shapes[i].disabled = is_open() or leaf_broken[i]


## +1 when the body at the sensor stands on the door's +Z side (in the door's own space), so
## the leaves swing toward -Z, away from him. Nobody pulls a door into his own face.
func _side_of_whoever_is_coming() -> float:
	for body: Node3D in _sensor.get_overlapping_bodies():
		var local: Vector3 = _visual.global_transform.affine_inverse() * body.global_position
		return 1.0 if local.z >= 0.0 else -1.0
	return _swing_sign


## Jambs, header and a dark glazed transom up to the lintel. Origin on the floor, mid-door.
static func _model_frame(kit: MeshKit) -> void:
	var steel: Material = Mats.gunmetal()
	var width: float = T.cell_size
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(JAMB, HEIGHT, 0.16), Vector3(side * (width - JAMB) * 0.5, HEIGHT * 0.5, 0), steel)
		kit.box(Vector3(0.025, HEIGHT, 0.20), Vector3(side * (width * 0.5 - JAMB - 0.0125), HEIGHT * 0.5, 0), Mats.locked())   # door stop
	kit.box(Vector3(width, 0.07, 0.16), Vector3(0, LEAF_HEIGHT + 0.045, 0), steel)            # header
	kit.box(Vector3(width, 0.05, 0.16), Vector3(0, HEIGHT - 0.025, 0), steel)                 # top rail
	kit.box(Vector3(width - JAMB * 2.0, HEIGHT - LEAF_HEIGHT - 0.13, 0.02), Vector3(0, (LEAF_HEIGHT + 0.08 + HEIGHT - 0.05) * 0.5, 0), Mats.polymer())   # transom glass
	kit.box(Vector3(0.03, HEIGHT - LEAF_HEIGHT - 0.13, 0.05), Vector3(0, (LEAF_HEIGHT + 0.08 + HEIGHT - 0.05) * 0.5, 0), steel)                         # its mullion
	kit.box(Vector3(width - JAMB * 2.0, 0.012, 0.14), Vector3(0, 0.006, 0), Mats.steel())     # threshold


## One leaf, hanging from its hinge edge at x = 0 and reaching along +X. Both faces are the same.
## The window by the meeting edge is a real opening glazed with glass, not a painted panel.
static func _model_leaf(kit: MeshKit) -> void:
	var w: float = T.cell_size * 0.5 - JAMB - 0.006
	var wood: Material = Mats.wood()
	var dark: Material = Mats.wood_dark()
	var metal: Material = Mats.steel()
	var y0: float = 0.012
	var top: float = y0 + LEAF_HEIGHT
	var cx: float = w - WINDOW_FROM_EDGE
	var x0: float = cx - WINDOW_SIZE.x * 0.5
	var x1: float = cx + WINDOW_SIZE.x * 0.5
	var wy0: float = WINDOW_Y - WINDOW_SIZE.y * 0.5
	var wy1: float = WINDOW_Y + WINDOW_SIZE.y * 0.5
	# The slab, in four pieces round the opening.
	kit.box(Vector3(x0, LEAF_HEIGHT, LEAF_THICKNESS), Vector3(x0 * 0.5, (y0 + top) * 0.5, 0), wood)
	kit.box(Vector3(w - x1, LEAF_HEIGHT, LEAF_THICKNESS), Vector3((x1 + w) * 0.5, (y0 + top) * 0.5, 0), wood)
	kit.box(Vector3(x1 - x0, wy0 - y0, LEAF_THICKNESS), Vector3(cx, (y0 + wy0) * 0.5, 0), wood)
	kit.box(Vector3(x1 - x0, top - wy1, LEAF_THICKNESS), Vector3(cx, (wy1 + top) * 0.5, 0), wood)
	kit.box(Vector3(WINDOW_SIZE.x, WINDOW_SIZE.y, 0.008), Vector3(cx, WINDOW_Y, 0), Mats.glass())      # the pane
	for face: float in [-1.0, 1.0]:
		var skin: float = LEAF_THICKNESS * 0.5 * face
		kit.box(Vector3(w - 0.03, 0.24, 0.004), Vector3(w * 0.5, 0.145, skin + 0.002 * face), metal)                 # kick plate
		# A sunk lower panel and a tall upper one, each a dark moulding round a lighter field.
		kit.box(Vector3(w * 0.72, 0.62, 0.006), Vector3(w * 0.5, 0.66, skin + 0.003 * face), dark)
		kit.box(Vector3(w * 0.62, 0.52, 0.004), Vector3(w * 0.5, 0.66, skin + 0.007 * face), wood)
		kit.box(Vector3(w * 0.44, 0.98, 0.006), Vector3(w * 0.34, 1.56, skin + 0.003 * face), dark)
		kit.box(Vector3(w * 0.34, 0.88, 0.004), Vector3(w * 0.34, 1.56, skin + 0.007 * face), wood)
		# Steel rim round the window, on both faces.
		kit.box(Vector3(WINDOW_SIZE.x + 0.05, 0.025, 0.008), Vector3(cx, wy1 + 0.0125, skin + 0.004 * face), metal)
		kit.box(Vector3(WINDOW_SIZE.x + 0.05, 0.025, 0.008), Vector3(cx, wy0 - 0.0125, skin + 0.004 * face), metal)
		kit.box(Vector3(0.025, WINDOW_SIZE.y, 0.008), Vector3(x0 - 0.0125, WINDOW_Y, skin + 0.004 * face), metal)
		kit.box(Vector3(0.025, WINDOW_SIZE.y, 0.008), Vector3(x1 + 0.0125, WINDOW_Y, skin + 0.004 * face), metal)
		# Lever handle on its plate.
		kit.box(Vector3(0.05, 0.22, 0.006), Vector3(w - 0.075, 1.02, skin + 0.003 * face), metal)
		kit.box(Vector3(0.022, 0.022, 0.05), Vector3(w - 0.075, 1.05, skin + 0.028 * face), metal)
		kit.box(Vector3(0.14, 0.022, 0.022), Vector3(w - 0.135, 1.05, skin + 0.052 * face), metal)
		kit.tube(0.011, 0.011, 0.008, Vector3(w - 0.075, 0.96, skin + 0.007 * face), Mats.polymer(), true, 10)      # keyhole
	for y: float in [0.26, 1.10, 1.94]:
		kit.tube(0.013, 0.013, 0.11, Vector3(0.0, y, 0.0), metal, false, 8)                                           # hinge barrels


static func damage_for(source: StringName) -> int:
	match source:
		&"punch":
			return T.door_damage_punch
		&"throw":
			return T.door_damage_throw
		&"bullet":
			return T.door_damage_bullet
	return 0


func on_punched(by: Node, at: Vector3) -> void:
	var dir: Vector3 = Vector3.ZERO
	if by is Node3D:
		dir = (global_position - (by as Node3D).global_position).normalized()
	take_damage(damage_for(&"punch"), dir, at)


func on_thrown_hit(item: Pickup) -> void:
	take_damage(damage_for(&"throw"), item.velocity.normalized(), item.global_position)


func on_bullet_hit(bullet: Node, point: Vector3, _normal: Vector3) -> void:
	var dir: Vector3 = (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO
	take_damage(damage_for(&"bullet"), dir, point)


func take_damage(amount: int, direction: Vector3, at: Vector3) -> void:
	if is_broken or amount <= 0:
		return
	Sfx.play(&"door_hit", global_position)
	var which: int = leaf_at(at)
	for i: int in 2:
		if which != -1 and which != i or leaf_broken[i]:
			continue
		leaf_hp[i] -= amount
		if leaf_hp[i] <= 0:
			_break_leaf(i, direction)
	hp = mini(leaf_hp[0] if not leaf_broken[0] else 99, leaf_hp[1] if not leaf_broken[1] else 99)
	if leaf_broken[0] and leaf_broken[1]:
		shatter(direction)


## Which leaf a hit at `at` lands on: 0, 1, or -1 for both (the seam between them, or a hit
## that did not come with a point on the door, such as a blast).
func leaf_at(at: Vector3) -> int:
	var local: Vector3 = _visual.global_transform.affine_inverse() * at
	if absf(local.x) < 0.06 or absf(local.x) > T.cell_size * 0.5 + 0.3 or absf(local.z) > 0.6 \
			or local.y < -0.3 or local.y > HEIGHT + 0.3:
		return -1
	return 0 if local.x < 0.0 else 1


## Everything at once: the ram, explosions.
func smash(direction: Vector3) -> void:
	take_damage(999, direction, global_position + Vector3(0, HEIGHT * 0.5, 0))


func _break_leaf(i: int, direction: Vector3) -> void:
	leaf_broken[i] = true
	_leaf_shapes[i].disabled = true
	_leaves[i].visible = false
	var centre: Vector3 = _visual.global_transform * Vector3((-1.0 if i == 0 else 1.0) * T.cell_size * 0.25, HEIGHT * 0.45, 0.0)
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	var half: Vector3 = _visual.global_transform.basis * Vector3(T.cell_size * 0.22, HEIGHT * 0.42, 0.05)
	half = half.abs()
	Shatter.burst(Game.entities_root(self), centre, 4, Mats.wood(), half, flat * 5.0, 0.5)
	Shatter.burst(Game.entities_root(self), centre + Vector3(0, 0.1, 0), 5, Mats.glass(), half * 0.3, flat * 3.5, 0.06)      # the window
	Shatter.burst(Game.entities_root(self), centre - Vector3(0, 0.4, 0), 3, Mats.steel(), half * 0.3, flat * 4.0, 0.06)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude == null or not dude.alive:
			continue
		var to_dude: Vector3 = dude.global_position - centre
		if to_dude.length() <= T.door_shard_stun_radius and (flat == Vector3.ZERO or to_dude.normalized().dot(flat) > -0.1):
			dude.stun(T.throw_stun)
	Sfx.play(&"door_break", centre)
	TimeManager.burst(T.burst_action, T.burst_strength_break)


func shatter(direction: Vector3) -> void:
	if is_broken:
		return
	for i: int in 2:
		if not leaf_broken[i]:
			_break_leaf(i, direction)
	is_broken = true
	# The leaves are matchwood. The steel frame they hung in stays in the wall.
	if get_parent() != null:
		_frame.reparent(get_parent())
	broken.emit(self)
	queue_free()
