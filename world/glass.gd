class_name GlassPane
extends StaticBody3D
## Blocks movement and carves the navmesh (layer 1), never blocks sight, breaks on any hit.

const T: Tuning = preload("res://data/tuning.tres")

var along_x: bool = true
var hp: int = 1
var is_broken: bool = false
## A window in the outer wall: once it is gone there is a frame, open air, and a long way down.
var opens_onto_the_drop: bool = false


func _ready() -> void:
	add_to_group(&"see_through")
	if opens_onto_the_drop:
		add_to_group(&"windows")
		_build_frame()
	collision_layer = 1 | 32
	collision_mask = 0
	hp = T.glass_hp
	var size := Vector3(T.cell_size, T.wall_height, 0.08) if along_x else Vector3(0.08, T.wall_height, T.cell_size)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = T.wall_height * 0.5
	add_child(shape)
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Mats.glass()
	panel.mesh = mesh
	panel.position.y = T.wall_height * 0.5
	add_child(panel)


func on_punched(by: Node, _at: Vector3) -> void:
	var dir: Vector3 = (global_position - (by as Node3D).global_position).normalized() if by is Node3D else Vector3.ZERO
	take_damage(1, dir)


func on_thrown_hit(item: Pickup) -> void:
	take_damage(1, item.velocity.normalized())


func on_bullet_hit(bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	take_damage(1, (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO)


func take_damage(amount: int, direction: Vector3) -> void:
	if is_broken:
		return
	hp -= amount
	if hp > 0:
		return
	is_broken = true
	var half := Vector3(T.cell_size * 0.45, T.wall_height * 0.45, 0.03) if along_x else Vector3(0.03, T.wall_height * 0.45, T.cell_size * 0.45)
	Shatter.burst(Game.entities_root(self), global_position + Vector3(0, T.wall_height * 0.5, 0), 18, Mats.glass(),
		half, Vector3(direction.x, 0, direction.z).normalized() * 3.0, 0.22)
	Sfx.play(&"shatter", global_position)
	if opens_onto_the_drop:
		# The frame stays and the hole stays: this is the way out of the building now.
		Game.open_windows.append(global_position)
		Game.window_broken.emit(global_position)
	queue_free()


## A window has a frame round it, so a hole in the wall still reads as a window.
func _build_frame() -> void:
	var frame := Node3D.new()
	frame.name = "WindowFrame"
	frame.top_level = true
	get_parent().call_deferred(&"add_child", frame)
	frame.set_deferred(&"global_position", global_position)
	var thickness: float = 0.16
	for part: Array in [[Vector3(T.cell_size, thickness, 0.34), Vector3(0, T.wall_height - thickness * 0.5, 0)],
			[Vector3(T.cell_size, thickness, 0.34), Vector3(0, thickness * 0.5, 0)],
			[Vector3(thickness, T.wall_height, 0.34), Vector3(T.cell_size * 0.5 - thickness * 0.5, T.wall_height * 0.5, 0)],
			[Vector3(thickness, T.wall_height, 0.34), Vector3(-T.cell_size * 0.5 + thickness * 0.5, T.wall_height * 0.5, 0)]]:
		var size: Vector3 = part[0]
		var at: Vector3 = part[1]
		if not along_x:
			size = Vector3(size.z, size.y, size.x)
			at = Vector3(at.z, at.y, at.x)
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = Mats.gunmetal()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = at
		frame.add_child(mi)
