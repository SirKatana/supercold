class_name LaserBeam
extends Node3D
## The super gun's beam: a white-hot core in an orange sheath with a light at the far end.
## It hangs in the air for a moment, then thins away. Real time, so the player always sees
## it however slow the world is.

var _core: MeshInstance3D
var _sheath: MeshInstance3D
var _light: OmniLight3D
var _age: float = 0.0
const LIFE: float = 0.28


static func draw(parent: Node, from: Vector3, to: Vector3) -> LaserBeam:
	var beam := LaserBeam.new()
	parent.add_child(beam)
	beam._build(from, to)
	return beam


func _tube(radius: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 0
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	global_position = (from + to) * 0.5
	var y: Vector3 = (to - from).normalized()
	var x: Vector3 = y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	global_transform.basis = Basis(x, y * length, x.cross(y).normalized())
	_core = _tube(0.018, Mats.laser())
	var sheath_material := StandardMaterial3D.new()
	sheath_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sheath_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheath_material.albedo_color = Color(1.0, 0.4, 0.05, 0.4)
	_sheath = _tube(0.06, sheath_material)
	_light = OmniLight3D.new()
	_light.top_level = true
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 5.0
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.global_position = to - y * 0.2


func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / LIFE, 0.0, 1.0)
	_core.scale = Vector3(1.0 - t, 1, 1.0 - t)
	_sheath.scale = Vector3(1.0 + t * 1.5, 1, 1.0 + t * 1.5)
	(_sheath.material_override as StandardMaterial3D).albedo_color.a = 0.4 * (1.0 - t)
	_light.light_energy = 5.0 * (1.0 - t)
	if t >= 1.0:
		queue_free()
