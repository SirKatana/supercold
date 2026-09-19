class_name Throwable
extends Pickup
## Office junk. Everything here is a one-shot stun when thrown.

const FRAGILE_KINDS: Array[StringName] = [&"bottle", &"mug"]


static func create(item_kind: StringName) -> Throwable:
	var t := Throwable.new()
	t.kind = item_kind
	t.fragile = item_kind in FRAGILE_KINDS
	t.name = String(item_kind).capitalize()
	return t


func _build_mesh(root: Node3D) -> void:
	match kind:
		&"bottle":
			_add_cylinder(root, 0.045, 0.30)
		&"mug":
			_add_cylinder(root, 0.055, 0.11)
		&"keyboard":
			add_box(root, Vector3(0.42, 0.03, 0.14), Vector3.ZERO)
		&"stapler":
			add_box(root, Vector3(0.06, 0.06, 0.17), Vector3.ZERO)
		_:
			add_box(root, Vector3.ONE * 0.15, Vector3.ZERO)


func _add_cylinder(root: Node3D, radius: float, height: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = Mats.black()
	mi.mesh = mesh
	mi.position.y = height * 0.5 - 0.05
	root.add_child(mi)
