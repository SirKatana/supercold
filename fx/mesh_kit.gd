class_name MeshKit
extends RefCounted
## Builds one detailed mesh out of many primitives. Every part is transformed on the CPU
## and merged per material, so a 100-part rifle costs one MeshInstance3D and a handful of
## surfaces instead of 100 draw calls. Results are cached by key and shared.

static var _cache: Dictionary[StringName, ArrayMesh] = {}
## In a browser every draw call is expensive, and a model drew once per material: a door was
## eleven. With this on, every plain opaque material in a model is folded into ONE surface that
## carries its colours per vertex. What stays separate: glowing, see-through, textured or unshaded
## materials, and the themed `Mats.prop()` panel colour, which is always surface 0 so a level's
## theme can recolour it. Tests flip it to cover both ways.
static var colour_merge: bool = OS.has_feature("web")
static var _vertex_colour_material: StandardMaterial3D

## Applied to every part added after it is set. Used for sub-assemblies like a raked grip.
var base: Transform3D = Transform3D.IDENTITY
## Applied to the whole model, outside `base`. Used to fix overall proportions.
var root: Transform3D = Transform3D.IDENTITY

var _verts: Dictionary[Material, PackedVector3Array] = {}
var _normals: Dictionary[Material, PackedVector3Array] = {}
var _indices: Dictionary[Material, PackedInt32Array] = {}


static func cached(key: StringName, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var kit := MeshKit.new()
		build.call(kit)
		_cache[key] = kit.bake()
	return _cache[key]


func add(mesh: PrimitiveMesh, local: Transform3D, material: Material) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if not _verts.has(material):
		_verts[material] = PackedVector3Array()
		_normals[material] = PackedVector3Array()
		_indices[material] = PackedInt32Array()
	var xform: Transform3D = root * base * local
	var normal_basis: Basis = xform.basis.inverse().transposed()
	var offset: int = _verts[material].size()
	var verts: PackedVector3Array = _verts[material]
	var normals: PackedVector3Array = _normals[material]
	var indices: PackedInt32Array = _indices[material]
	for i: int in src_verts.size():
		verts.append(xform * src_verts[i])
		normals.append((normal_basis * src_normals[i]).normalized())
	for index: int in src_indices:
		indices.append(offset + index)
	_verts[material] = verts
	_normals[material] = normals
	_indices[material] = indices


func box(size: Vector3, at: Vector3, material: Material, euler: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	add(mesh, Transform3D(Basis.from_euler(euler), at), material)


## A cylinder or cone. `along_z` lays it down the barrel axis instead of standing up.
func tube(top_radius: float, bottom_radius: float, length: float, at: Vector3, material: Material,
		along_z: bool = true, segments: int = 12, euler: Vector3 = Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = length
	mesh.radial_segments = segments
	mesh.rings = 0
	var basis: Basis = Basis.from_euler(euler)
	if along_z:
		# The cylinder's top (+Y) ends up at -Z, the muzzle end.
		basis = basis * Basis(Vector3.RIGHT, -PI * 0.5)
	add(mesh, Transform3D(basis, at), material)


func ball(radius: float, at: Vector3, material: Material, squash: Vector3 = Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	add(mesh, Transform3D(Basis.from_scale(squash), at), material)


static func _mergeable(material: Material) -> bool:
	var m: StandardMaterial3D = material as StandardMaterial3D
	return m != null and m != Mats.prop() and not m.emission_enabled \
		and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and m.albedo_texture == null \
		and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL


static func vertex_colour_material() -> StandardMaterial3D:
	if _vertex_colour_material == null:
		_vertex_colour_material = StandardMaterial3D.new()
		_vertex_colour_material.vertex_color_use_as_albedo = true
		_vertex_colour_material.vertex_color_is_srgb = true
		_vertex_colour_material.albedo_color = Color.WHITE
		_vertex_colour_material.roughness = 0.7
		_vertex_colour_material.metallic = 0.1
	return _vertex_colour_material


func bake() -> ArrayMesh:
	if colour_merge:
		return _bake_merged()
	var out := ArrayMesh.new()
	for material: Material in _verts:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts[material]
		arrays[Mesh.ARRAY_NORMAL] = _normals[material]
		arrays[Mesh.ARRAY_INDEX] = _indices[material]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, material)
	return out


func _bake_merged() -> ArrayMesh:
	var out := ArrayMesh.new()
	var keep: Array[Material] = []
	var merged_verts := PackedVector3Array()
	var merged_normals := PackedVector3Array()
	var merged_colours := PackedColorArray()
	var merged_indices := PackedInt32Array()
	for material: Material in _verts:
		if not _mergeable(material):
			keep.append(material)
			continue
		var colour: Color = (material as StandardMaterial3D).albedo_color
		var offset: int = merged_verts.size()
		merged_verts.append_array(_verts[material])
		merged_normals.append_array(_normals[material])
		for i: int in _verts[material].size():
			merged_colours.append(colour)
		for index: int in _indices[material]:
			merged_indices.append(offset + index)
	# The themed panel colour first, as surface 0, then everything plain in one, then the rest.
	keep.sort_custom(func(a: Material, b: Material) -> bool: return a == Mats.prop() and b != Mats.prop())
	var ordered: Array = []
	if not keep.is_empty() and keep[0] == Mats.prop():
		ordered.append(keep.pop_front())
	if not merged_verts.is_empty():
		ordered.append(null)
	ordered.append_array(keep)
	for material: Variant in ordered:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		if material == null:
			arrays[Mesh.ARRAY_VERTEX] = merged_verts
			arrays[Mesh.ARRAY_NORMAL] = merged_normals
			arrays[Mesh.ARRAY_COLOR] = merged_colours
			arrays[Mesh.ARRAY_INDEX] = merged_indices
		else:
			arrays[Mesh.ARRAY_VERTEX] = _verts[material]
			arrays[Mesh.ARRAY_NORMAL] = _normals[material]
			arrays[Mesh.ARRAY_INDEX] = _indices[material]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, vertex_colour_material() if material == null else material)
	return out


func part_count_hint() -> int:
	var total: int = 0
	for material: Material in _indices:
		total += _indices[material].size()
	return total
