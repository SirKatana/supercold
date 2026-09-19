class_name WallBreach
extends RefCounted
## Knocking holes in interior walls. The level is a grid, so a breach removes one 2 m cell:
## the merged wall body that covered it is replaced by up to four smaller ones, the grid
## gets a floor cell, the navmesh is rebaked, and rubble flies.

const T: Tuning = preload("res://data/tuning.tres")


static func cell_of(data: LevelData, point: Vector3, normal: Vector3) -> Vector2i:
	var inside: Vector3 = point - normal * 0.25
	return Vector2i(floori(inside.x / data.cell_size), floori(inside.z / data.cell_size))


## Outer walls, and walls next to the void outside the building, never break.
static func can_break(data: LevelData, cell: Vector2i) -> bool:
	if data.char_at(cell) != "#":
		return false
	if cell.x <= 0 or cell.y <= 0 or cell.x >= data.width - 1 or cell.y >= data.height - 1:
		return false
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if data.char_at(cell + Vector2i(dx, dy)) == " ":
				return false
	return true


## One bash on a wall. Returns true if the wall took it (cracked or broke), false if it is unbreakable.
static func bash(wall: StaticBody3D, point: Vector3, normal: Vector3, direction: Vector3) -> bool:
	var data: LevelData = Game.data
	var level: Node3D = Game.level
	if data == null or level == null or not wall.has_meta(&"rect"):
		return false
	var cell: Vector2i = cell_of(data, point, normal)
	if not can_break(data, cell):
		Sfx.play(&"door_hit", point)
		return false
	var hits: Dictionary = level.get_meta(&"wall_hits", {})
	hits[cell] = int(hits.get(cell, 0)) + 1
	level.set_meta(&"wall_hits", hits)
	TimeManager.burst(T.burst_action, T.burst_strength_break)
	if hits[cell] >= T.ram_wall_hits:
		break_cell(level, data, wall, cell, direction)
	else:
		_add_cracks(level, cell, point, normal)
		Sfx.play(&"door_hit", point)
		Shatter.burst(Game.entities_root(wall), point + normal * 0.1, 5, Mats.wall(), Vector3.ONE * 0.15, normal * 2.0, 0.09)
	return true


static func split_rect(rect: Rect2i, cell: Vector2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var candidates: Array[Rect2i] = [
		Rect2i(rect.position.x, rect.position.y, rect.size.x, cell.y - rect.position.y),
		Rect2i(rect.position.x, cell.y + 1, rect.size.x, rect.end.y - cell.y - 1),
		Rect2i(rect.position.x, cell.y, cell.x - rect.position.x, 1),
		Rect2i(cell.x + 1, cell.y, rect.end.x - cell.x - 1, 1),
	]
	for r: Rect2i in candidates:
		if r.size.x > 0 and r.size.y > 0:
			out.append(r)
	return out


static func break_cell(level: Node3D, data: LevelData, wall: StaticBody3D, cell: Vector2i, direction: Vector3) -> void:
	var rect: Rect2i = wall.get_meta(&"rect")
	var parent: Node3D = wall.get_parent()
	parent.remove_child(wall)
	wall.queue_free()
	for r: Rect2i in split_rect(rect, cell):
		LevelBuilder.add_wall_rect(data, parent, r)
	var row: String = data.rows[cell.y]
	data.rows[cell.y] = row.substr(0, cell.x) + "." + row.substr(cell.x + 1)

	var cracks: Node = level.get_node_or_null("Cracks_%d_%d" % [cell.x, cell.y])
	if cracks != null:
		cracks.queue_free()

	var centre: Vector3 = data.cell_center(cell, T.wall_height * 0.5)
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	var entities: Node = Game.entities_root(level)
	Shatter.burst(entities, centre, 22, Mats.wall(), Vector3(0.8, 1.3, 0.8), flat * 4.0, 0.34)
	_add_rubble(level, data, cell)
	for node: Node in level.get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude != null and dude.alive and dude.global_position.distance_to(data.cell_center(cell)) <= T.door_shard_stun_radius + 0.5:
			dude.stun(T.throw_stun)
	Sfx.play(&"door_break", centre)
	Game.emit_noise(centre, T.dude_hearing * 1.5)
	# Threaded, so a breach never hitches the frame. Dudes use the new opening a moment later.
	(level.get_node(^"Nav") as NavigationRegion3D).bake_navigation_mesh(true)


## Jagged leftovers around the hole so it reads as broken, not as a neat doorway.
static func _add_rubble(level: Node3D, data: LevelData, cell: Vector2i) -> void:
	var holder := Node3D.new()
	holder.name = "Rubble_%d_%d" % [cell.x, cell.y]
	level.add_child(holder)
	holder.position = data.cell_center(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	for i: int in 9:
		var chunk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(0.15, 0.4), rng.randf_range(0.08, 0.3), rng.randf_range(0.15, 0.4))
		mesh.material = Mats.wall()
		chunk.mesh = mesh
		chunk.position = Vector3(rng.randf_range(-0.9, 0.9), mesh.size.y * 0.5, rng.randf_range(-0.9, 0.9))
		chunk.rotation.y = rng.randf() * TAU
		holder.add_child(chunk)
	for i: int in 7:    # broken teeth hanging from the top edge
		var tooth := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(0.2, 0.5), rng.randf_range(0.15, 0.55), rng.randf_range(0.2, 0.5))
		mesh.material = Mats.wall()
		tooth.mesh = mesh
		tooth.position = Vector3(rng.randf_range(-0.85, 0.85), T.wall_height - mesh.size.y * 0.5, rng.randf_range(-0.85, 0.85))
		holder.add_child(tooth)


static func _add_cracks(level: Node3D, cell: Vector2i, point: Vector3, normal: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Cracks_%d_%d" % [cell.x, cell.y]
	level.add_child(holder)
	holder.global_position = point + normal * 0.012
	var up: Vector3 = Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	holder.look_at(holder.global_position + normal, up)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell) + 7
	for i: int in 9:
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.018, rng.randf_range(0.35, 0.95), 0.006)
		mesh.material = Mats.locked()
		line.mesh = mesh
		var angle: float = TAU * i / 9.0 + rng.randf_range(-0.3, 0.3)
		line.rotation.z = angle
		line.position = Vector3(-sin(angle), cos(angle), 0) * mesh.size.y * 0.5
		holder.add_child(line)
