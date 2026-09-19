class_name LevelBuilder
extends RefCounted
## Builds a playable Node3D tree from LevelData. Static geometry goes under a
## NavigationRegion3D so the navmesh can be baked from its colliders.

const T: Tuning = preload("res://data/tuning.tres")
const LAYER_WORLD: int = 1


static func build(data: LevelData) -> Node3D:
	var level := Node3D.new()
	level.name = "Level"
	level.set_meta(&"data", data)

	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	level.add_child(nav)

	var entities := Node3D.new()
	entities.name = "Entities"
	level.add_child(entities)

	_build_floor(data, nav)
	_build_walls(data, nav)
	_build_props(data, nav)
	if not data.open_sky:
		_build_ceiling(data, level)
	_place_pickups(data, nav, entities)
	return level


static func create_pickup(kind: StringName) -> Pickup:
	if kind == &"pistol":
		return Pistol.create()
	return Throwable.create(kind)


## Items sit on a small pedestal so they read at hand height against the white floor.
static func _place_pickups(data: LevelData, geometry: Node3D, entities: Node3D) -> void:
	for entry: Dictionary in data.pickups:
		var pedestal: StaticBody3D = make_box(Vector3(0.7, 0.9, 0.7), Mats.prop())
		pedestal.name = "Pedestal"
		pedestal.position = data.cell_center(entry["cell"], 0.45)
		geometry.add_child(pedestal)
		var item: Pickup = create_pickup(entry["kind"])
		item.position = data.cell_center(entry["cell"], 0.9 + Pickup.REST_HEIGHT)
		entities.add_child(item)


static func make_box(size: Vector3, material: Material, layer: int = LAYER_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	return body


static func _build_floor(data: LevelData, parent: Node3D) -> void:
	var size := Vector3(data.width * data.cell_size, 0.5, data.height * data.cell_size)
	var body: StaticBody3D = make_box(size, Mats.floor_mat())
	body.name = "Floor"
	body.position = Vector3(size.x * 0.5, -0.25, size.z * 0.5)
	parent.add_child(body)


static func _build_ceiling(data: LevelData, parent: Node3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(data.width * data.cell_size, 0.2, data.height * data.cell_size)
	mesh.material = Mats.wall()
	mesh_instance.mesh = mesh
	mesh_instance.name = "Ceiling"
	mesh_instance.position = Vector3(mesh.size.x * 0.5, T.wall_height + 0.1, mesh.size.z * 0.5)
	parent.add_child(mesh_instance)


## Merges wall cells into rectangles: runs along each row, then identical runs stacked down rows.
static func wall_rects(data: LevelData) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var open: Dictionary[Vector2i, int] = {}  # (x0, x1) -> index into rects
	for y: int in data.height:
		var next_open: Dictionary[Vector2i, int] = {}
		var x: int = 0
		while x < data.width:
			if data.rows[y][x] != "#":
				x += 1
				continue
			var x0: int = x
			while x < data.width and data.rows[y][x] == "#":
				x += 1
			var key := Vector2i(x0, x)
			if open.has(key):
				var index: int = open[key]
				rects[index] = Rect2i(rects[index].position, rects[index].size + Vector2i(0, 1))
				next_open[key] = index
			else:
				rects.append(Rect2i(x0, y, x - x0, 1))
				next_open[key] = rects.size() - 1
		open = next_open
	return rects


static func _build_walls(data: LevelData, parent: Node3D) -> void:
	for rect: Rect2i in wall_rects(data):
		var size := Vector3(rect.size.x * data.cell_size, T.wall_height, rect.size.y * data.cell_size)
		var body: StaticBody3D = make_box(size, Mats.wall())
		body.name = "Wall"
		body.position = Vector3(
			(rect.position.x + rect.size.x * 0.5) * data.cell_size,
			T.wall_height * 0.5,
			(rect.position.y + rect.size.y * 0.5) * data.cell_size)
		parent.add_child(body)


static func _build_props(data: LevelData, parent: Node3D) -> void:
	for prop: Dictionary in data.props:
		var kind: StringName = prop["kind"]
		var size := Vector3(1.7, 1.0, 0.9) if kind == &"desk" else Vector3(1.0, 2.4, 1.7)
		var body: StaticBody3D = make_box(size, Mats.prop())
		body.name = String(kind).capitalize()
		body.position = data.cell_center(prop["cell"], size.y * 0.5)
		parent.add_child(body)
