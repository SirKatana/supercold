class_name ElevatorButton
extends StaticBody3D
## The call button. Sits on the breakables layer so a punch, a bullet or a thrown
## object all reach it. It never breaks, it just reports the press.

signal pressed

var _cap: MeshInstance3D


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.34, 0.44, 0.14)   # generous, it has to be hittable from across a room
	shape.shape = box
	add_child(shape)

	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.20, 0.32, 0.03)
	plate_mesh.material = Mats.steel()
	plate.mesh = plate_mesh
	add_child(plate)

	_cap = MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.055
	cap_mesh.bottom_radius = 0.055
	cap_mesh.height = 0.03
	cap_mesh.radial_segments = 16
	_cap.mesh = cap_mesh
	_cap.rotation.x = PI * 0.5
	_cap.position.z = -0.025
	add_child(_cap)
	set_lit(false)


func set_lit(lit: bool) -> void:
	(_cap.mesh as CylinderMesh).material = Mats.accent() if lit else Mats.locked()


func on_punched(_by: Node, _at: Vector3) -> void:
	pressed.emit()


func on_bullet_hit(_bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	pressed.emit()


func on_thrown_hit(_item: Pickup) -> void:
	pressed.emit()
