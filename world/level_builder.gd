class_name LevelBuilder
extends RefCounted
## Builds a playable Node3D tree from LevelData. Static geometry goes under a
## NavigationRegion3D so the navmesh can be baked from its colliders.

const T: Tuning = preload("res://data/tuning.tres")
const LAYER_WORLD: int = 1

## This floor's materials. Set at the start of build(), and still right when WallBreach
## rebuilds a wall later on the same floor.
static var wall_material: Material
static var floor_material: Material
static var prop_material: Material


static func _themed(base: StandardMaterial3D, hex: Variant) -> Material:
	if not hex is String:
		return base
	var m: StandardMaterial3D = base.duplicate()
	m.albedo_color = Color(hex as String)
	return m


static func apply_theme(data: LevelData) -> void:
	wall_material = _themed(Mats.wall(), data.theme.get("wall"))
	floor_material = _themed(Mats.floor_mat(), data.theme.get("floor"))
	prop_material = _themed(Mats.prop(), data.theme.get("prop"))


static func build(data: LevelData) -> Node3D:
	apply_theme(data)
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
	_place_breakables(data, nav, entities)
	_place_exit_and_triggers(data, nav, entities)
	_place_hazards(data, entities)
	_build_pools(data, level, entities)
	return level


static func _place_breakables(data: LevelData, geometry: Node3D, entities: Node3D) -> void:
	for entry: Dictionary in data.doors:
		var door := Door.new()
		door.name = "Door"
		door.along_x = entry["along_x"]
		door.position = data.cell_center(entry["cell"])
		entities.add_child(door)
		# Lintel and jambs fill the rest of the cell so the opening reads as a doorway.
		var lintel_h: float = T.wall_height - Door.HEIGHT
		var lintel_size := Vector3(data.cell_size, lintel_h, 0.3) if door.along_x else Vector3(0.3, lintel_h, data.cell_size)
		var lintel: StaticBody3D = make_box(lintel_size, Mats.wall())
		lintel.name = "Lintel"
		lintel.position = data.cell_center(entry["cell"], Door.HEIGHT + lintel_h * 0.5)
		geometry.add_child(lintel)
	for entry: Dictionary in data.glass:
		var pane := GlassPane.new()
		pane.name = "Glass"
		pane.along_x = entry["along_x"]
		pane.position = data.cell_center(entry["cell"])
		# Under Nav so the pane carves the navmesh.
		geometry.add_child(pane)


static func _place_hazards(data: LevelData, entities: Node3D) -> void:
	for entry: Dictionary in data.puddles:
		var puddle := Puddle.new()
		puddle.name = "Ice" if entry["icy"] else "Water"
		puddle.icy = entry["icy"]
		puddle.position = data.cell_center(entry["cell"])
		entities.add_child(puddle)
	for cell: Vector2i in data.fart_cells:
		var cloud := FartCloud.new()
		cloud.name = "FartCloud"
		cloud.position = data.cell_center(cell, 1.1)
		entities.add_child(cloud)


static func elevator_transform(data: LevelData, cell: Vector2i) -> Transform3D:
	var dir: Vector2i = data.door_direction(cell)
	# The cabin's doors are on its local -Z side.
	return Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), data.cell_center(cell))


static func _add_elevator(data: LevelData, cell: Vector2i, mode: Elevator.Mode, node_name: String,
		geometry: Node3D, entities: Node3D) -> void:
	var xform: Transform3D = elevator_transform(data, cell)
	Elevator.build_shell(geometry, xform)
	var lift := Elevator.new()
	lift.name = node_name
	lift.mode = mode
	lift.transform = xform
	entities.add_child(lift)


static func _place_exit_and_triggers(data: LevelData, geometry: Node3D, entities: Node3D) -> void:
	_add_elevator(data, data.player_start, Elevator.Mode.ARRIVAL, "Arrival", geometry, entities)
	if data.exit_kind == &"helipad":
		var pad := Helipad.new()
		pad.name = "Exit"
		pad.position = data.cell_center(data.exit_cell)
		entities.add_child(pad)
	else:
		_add_elevator(data, data.exit_cell, Elevator.Mode.EXIT, "Exit", geometry, entities)
	for cell: Vector2i in data.triggers:
		var zone := TriggerZone.new()
		zone.name = "Trigger"
		zone.position = data.cell_center(cell)
		entities.add_child(zone)


static func create_pickup(kind: StringName) -> Pickup:
	if kind == &"pistol":
		return Pistol.create()
	if kind == &"ram":
		return Ram.create()
	if kind == &"rifle":
		return Rifle.create()
	if kind == &"shotgun":
		return Shotgun.create()
	if kind == &"barrel":
		return GasBarrel.create()
	if kind == &"knife":
		return Knife.create()
	if kind == &"freeze":
		return FreezeBomb.create()
	if kind == &"smg" or kind == &"revolver" or kind == &"sniper" or kind == &"super":
		return PinkDude.create_gun(kind)
	return Throwable.create(kind)


## Items sit on a small pedestal so they read at hand height against the white floor.
static func _place_pickups(data: LevelData, geometry: Node3D, entities: Node3D) -> void:
	for entry: Dictionary in data.pickups:
		if entry["kind"] == &"barrel":
			# Barrels stand on the floor, not on a pedestal.
			var barrel: Pickup = create_pickup(&"barrel")
			barrel.position = data.cell_center(entry["cell"], 0.0)
			entities.add_child(barrel)
			continue
		var pedestal: StaticBody3D = make_box(Vector3(0.7, 0.9, 0.7), prop_material)
		pedestal.name = "Pedestal"
		pedestal.position = data.cell_center(entry["cell"], 0.45)
		geometry.add_child(pedestal)
		var item: Pickup = create_pickup(entry["kind"])
		item.position = data.cell_center(entry["cell"], 0.9 + Pickup.REST_HEIGHT)
		entities.add_child(item)


## Bakes the navmesh from layer-1 static colliders under `Nav`. Must run with the level in the tree.
## Mesh parsing is avoided on purpose: it yields nothing under --headless.
static func bake_navigation(level: Node3D, _data: LevelData) -> void:
	var region: NavigationRegion3D = level.get_node(^"Nav")
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = LAYER_WORLD
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	# No baking AABB: clipping it below wall height turns every wall into a low walkable platform.
	# Wall and prop tops become unreachable islands instead, which is harmless.
	region.navigation_mesh = mesh
	region.bake_navigation_mesh(false)


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


## Merges every cell that passes `wanted` into rectangles, the same way walls are merged.
static func cell_rects(data: LevelData, wanted: Callable) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var open: Dictionary[Vector2i, int] = {}
	for y: int in data.height:
		var next_open: Dictionary[Vector2i, int] = {}
		var x: int = 0
		while x < data.width:
			if not wanted.call(data.rows[y][x]):
				x += 1
				continue
			var x0: int = x
			while x < data.width and wanted.call(data.rows[y][x]):
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


static func _rect_box(data: LevelData, rect: Rect2i, top: float, thickness: float, material: Material) -> StaticBody3D:
	var size := Vector3(rect.size.x * data.cell_size, thickness, rect.size.y * data.cell_size)
	var body: StaticBody3D = make_box(size, material)
	body.position = Vector3((rect.position.x + rect.size.x * 0.5) * data.cell_size, top - thickness * 0.5,
		(rect.position.y + rect.size.y * 0.5) * data.cell_size)
	return body


static func _build_floor(data: LevelData, parent: Node3D) -> void:
	if data.deep_cells.is_empty():
		var size := Vector3(data.width * data.cell_size, 0.5, data.height * data.cell_size)
		var body: StaticBody3D = make_box(size, floor_material)
		body.name = "Floor"
		body.position = Vector3(size.x * 0.5, -0.25, size.z * 0.5)
		parent.add_child(body)
		return
	# A floor with a pool in it: slabs everywhere except over the water, and thick enough
	# that their cut sides are the pool walls.
	var thick: float = T.pool_depth + 0.4
	for rect: Rect2i in cell_rects(data, func(c: String) -> bool: return c != "W"):
		var slab: StaticBody3D = _rect_box(data, rect, 0.0, thick, floor_material)
		slab.name = "Floor"
		parent.add_child(slab)


## The basin under each pool: tiled bottom with lane lines, the water itself, and ladder rails.
## The bottom is NOT under the navmesh parent, so dudes never try to path across it.
static func _build_pools(data: LevelData, level: Node3D, entities: Node3D) -> void:
	for rect: Rect2i in cell_rects(data, func(c: String) -> bool: return c == "W"):
		var bottom: StaticBody3D = _rect_box(data, rect, -T.pool_depth, 0.4, Mats.pool_tile())
		bottom.name = "PoolBottom"
		level.add_child(bottom)
		var centre := Vector3((rect.position.x + rect.size.x * 0.5) * data.cell_size, 0.0, (rect.position.y + rect.size.y * 0.5) * data.cell_size)
		var long_x: bool = rect.size.x >= rect.size.y
		var lanes: int = maxi(2, int((rect.size.y if long_x else rect.size.x) * data.cell_size / 2.5))
		for i: int in range(1, lanes):
			var line := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			var across: float = (rect.size.y if long_x else rect.size.x) * data.cell_size
			var along: float = (rect.size.x if long_x else rect.size.y) * data.cell_size - 3.0
			mesh.size = Vector3(along, 0.02, 0.25) if long_x else Vector3(0.25, 0.02, along)
			mesh.material = Mats.pool_line()
			line.mesh = mesh
			var offset: float = -across * 0.5 + across * i / lanes
			line.position = centre + Vector3(0.0 if long_x else offset, -T.pool_depth + 0.012, offset if long_x else 0.0)
			level.add_child(line)
		# Pale tile lining the four walls, so the sides are not the colour of the deck.
		for side: int in 4:
			var lining := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			var along_x: bool = side < 2
			var length: float = (rect.size.x if along_x else rect.size.y) * data.cell_size
			mesh.size = Vector3(length, T.pool_depth, 0.04) if along_x else Vector3(0.04, T.pool_depth, length)
			mesh.material = Mats.pool_tile()
			lining.mesh = mesh
			var half: float = (rect.size.y if along_x else rect.size.x) * data.cell_size * 0.5 - 0.02
			var sign: float = -1.0 if side % 2 == 0 else 1.0
			lining.position = centre + Vector3(0.0 if along_x else half * sign, -T.pool_depth * 0.5, half * sign if along_x else 0.0)
			level.add_child(lining)
		# Ladder rails at two corners.
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
			for rail: float in [-0.25, 0.25]:
				var tube := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.025
				mesh.bottom_radius = 0.025
				mesh.height = 1.9
				mesh.material = Mats.steel()
				tube.mesh = mesh
				tube.position = centre + Vector3(corner.x * (rect.size.x * data.cell_size * 0.5 - 0.12), -0.25,
					corner.y * (rect.size.y * data.cell_size * 0.5 - 1.0) + rail)
				level.add_child(tube)
		var water := DeepWater.new()
		water.name = "Pool"
		water.rect = rect
		water.cell_size = data.cell_size
		water.position = centre
		entities.add_child(water)


static func _build_ceiling(data: LevelData, parent: Node3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(data.width * data.cell_size, 0.2, data.height * data.cell_size)
	mesh.material = wall_material
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


static func add_wall_rect(data: LevelData, parent: Node3D, rect: Rect2i) -> StaticBody3D:
	var size := Vector3(rect.size.x * data.cell_size, T.wall_height, rect.size.y * data.cell_size)
	var body: StaticBody3D = make_box(size, wall_material if wall_material != null else Mats.wall())
	body.name = "Wall"
	body.add_to_group(&"walls")
	# WallBreach needs to know which cells this body stands for.
	body.set_meta(&"rect", rect)
	body.position = Vector3(
		(rect.position.x + rect.size.x * 0.5) * data.cell_size,
		T.wall_height * 0.5,
		(rect.position.y + rect.size.y * 0.5) * data.cell_size)
	parent.add_child(body)
	return body


static func _build_walls(data: LevelData, parent: Node3D) -> void:
	for rect: Rect2i in wall_rects(data):
		add_wall_rect(data, parent, rect)


static func _build_props(data: LevelData, parent: Node3D) -> void:
	for prop: Dictionary in data.props:
		var kind: StringName = prop["kind"]
		var size := Vector3(1.0, 2.4, 1.7)
		if kind == &"desk":
			size = Vector3(1.7, 1.0, 0.9)
		elif kind == &"pillar":
			size = Vector3(1.1, T.wall_height, 1.1)
		var body: StaticBody3D = make_box(size, prop_material)
		body.name = String(kind).capitalize()
		body.position = data.cell_center(prop["cell"], size.y * 0.5)
		parent.add_child(body)
