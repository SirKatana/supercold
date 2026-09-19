class_name GlassPane
extends StaticBody3D
## Blocks movement and carves the navmesh (layer 1), never blocks sight, breaks on any hit.

const T: Tuning = preload("res://data/tuning.tres")

var along_x: bool = true
var hp: int = 1
var is_broken: bool = false


func _ready() -> void:
	add_to_group(&"see_through")
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
	queue_free()
