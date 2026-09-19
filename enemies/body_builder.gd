class_name BodyBuilder
extends RefCounted
## Builds the low-poly pink humanoid from primitives. Returns the joints the
## dude animates: arm_l, arm_r, leg_l, leg_r pivots, the hand, and the root.


static func build(parent: Node3D) -> Dictionary[StringName, Node3D]:
	var root := Node3D.new()
	root.name = "Body"
	parent.add_child(root)
	var parts: Dictionary[StringName, Node3D] = {&"root": root}

	_box(root, Vector3(0.44, 0.62, 0.24), Vector3(0, 1.17, 0))  # torso
	_box(root, Vector3(0.36, 0.16, 0.22), Vector3(0, 0.80, 0))  # hips

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.30
	head_mesh.radial_segments = 7
	head_mesh.rings = 4
	head_mesh.material = Mats.pink()
	head.mesh = head_mesh
	head.position = Vector3(0, 1.66, 0)
	root.add_child(head)
	parts[&"head"] = head

	parts[&"arm_l"] = _limb(root, Vector3(-0.29, 1.43, 0), Vector3(0.11, 0.62, 0.11))
	parts[&"arm_r"] = _limb(root, Vector3(0.29, 1.43, 0), Vector3(0.11, 0.62, 0.11))
	parts[&"leg_l"] = _limb(root, Vector3(-0.11, 0.78, 0), Vector3(0.15, 0.78, 0.15))
	parts[&"leg_r"] = _limb(root, Vector3(0.11, 0.78, 0), Vector3(0.15, 0.78, 0.15))

	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.66, 0)
	# When the arm is raised 90 degrees the hand's -Z must point forward.
	hand.rotation.x = -PI * 0.5
	parts[&"arm_r"].add_child(hand)
	parts[&"hand"] = hand
	return parts


static func _box(parent: Node3D, size: Vector3, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Mats.pink()
	mi.mesh = mesh
	mi.position = at
	parent.add_child(mi)
	return mi


## A pivot at the joint with the limb box hanging below it.
static func _limb(parent: Node3D, joint: Vector3, size: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	parent.add_child(pivot)
	_box(pivot, size, Vector3(0, -size.y * 0.5, 0))
	return pivot
