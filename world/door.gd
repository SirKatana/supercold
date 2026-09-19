class_name Door
extends StaticBody3D
## Breakable door. The player smashes it; dudes just walk up and it slides open for them.

signal broken(door: Door)

const T: Tuning = preload("res://data/tuning.tres")
const HEIGHT: float = 2.6
const THICKNESS: float = 0.12

var along_x: bool = true
var hp: int = 2
var open_amount: float = 0.0
var is_broken: bool = false

var _shape: CollisionShape3D
var _panel: MeshInstance3D
var _sensor: Area3D


func _ready() -> void:
	add_to_group(&"doors")
	collision_layer = 32
	collision_mask = 0
	hp = T.door_hp
	var width: float = T.cell_size
	var size := Vector3(width, HEIGHT, THICKNESS) if along_x else Vector3(THICKNESS, HEIGHT, width)

	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = HEIGHT * 0.5
	add_child(_shape)

	_panel = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Mats.door()
	_panel.mesh = mesh
	_panel.position.y = HEIGHT * 0.5
	add_child(_panel)

	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 4
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
	open_amount = move_toward(open_amount, wanted, wd * 4.0)
	_panel.position.y = HEIGHT * 0.5 + open_amount * (HEIGHT - 0.1)
	_shape.disabled = is_open()


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


func take_damage(amount: int, direction: Vector3, _at: Vector3) -> void:
	if is_broken or amount <= 0:
		return
	hp -= amount
	Sfx.play(&"door_hit", global_position)
	if hp <= 0:
		shatter(direction)


func shatter(direction: Vector3) -> void:
	is_broken = true
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	var half := Vector3(T.cell_size * 0.45, HEIGHT * 0.45, 0.05) if along_x else Vector3(0.05, HEIGHT * 0.45, T.cell_size * 0.45)
	Shatter.burst(Game.entities_root(self), global_position + Vector3(0, HEIGHT * 0.5, 0), 6, Mats.door(),
		half, flat * 5.0, 0.55)
	# Flying panels stun whoever was standing behind the door.
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude == null or not dude.alive:
			continue
		var to_dude: Vector3 = dude.global_position - global_position
		if to_dude.length() <= T.door_shard_stun_radius and (flat == Vector3.ZERO or to_dude.normalized().dot(flat) > -0.1):
			dude.stun(T.throw_stun)
	Sfx.play(&"door_break", global_position)
	TimeManager.burst(T.burst_action)
	broken.emit(self)
	queue_free()
