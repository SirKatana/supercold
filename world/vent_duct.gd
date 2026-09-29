class_name VentDuct
extends RefCounted
## The crawl ducts. A `v` cell in a grid is a length of ventilation duct running through the
## wall: a square tunnel `HEIGHT` high with the wall above it, and a grate wherever it opens
## into a room. Crawl in at one grate and out at another, past everyone in the corridor.
##
## Dudes never use them: the tunnel is shorter than the navmesh's agent, so the bake ignores it.

const HEIGHT: float = 1.15
const WIDTH: float = 1.10
const GRATE_THICKNESS: float = 0.09


## Builds every duct cell and its grates. `geometry` takes the solid parts (they are world
## collision like any wall), `entities` the grates, which can be broken.
static func build(data: LevelData, geometry: Node3D, entities: Node3D) -> void:
	var cell: float = data.cell_size
	var side: float = (cell - WIDTH) * 0.5
	for y: int in data.height:
		for x: int in data.width:
			var kind: String = data.rows[y][x]
			if kind != "v" and kind != "e":
				continue
			var here := Vector2i(x, y)
			var centre: Vector3 = data.cell_center(here, 0.0)
			if (x * 7 + y * 5) % 3 == 0:
				var lamp := DuctLamp.new()
				geometry.add_child(lamp)
				lamp.position = centre + Vector3(0, HEIGHT - 0.06, 0)
			# A metal floor over the room's, so the whole tube is sheet metal.
			var pan := MeshInstance3D.new()
			var pan_mesh := BoxMesh.new()
			pan_mesh.size = Vector3(cell, 0.04, cell)
			pan_mesh.material = Mats.duct_metal()
			pan.mesh = pan_mesh
			pan.position = centre + Vector3(0, 0.021, 0)
			pan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			geometry.add_child(pan)
			# The wall above the tunnel, so a duct still reads as a wall from the room.
			_slab(geometry, Vector3(cell, T.wall_height - HEIGHT, cell),
				centre + Vector3(0, HEIGHT + (T.wall_height - HEIGHT) * 0.5, 0))
			# Which way does the tunnel run through this cell? A cell can connect on both
			# axes, and then it is an open junction: no side walls at all, or they would
			# seal the turn.
			var opens_x: bool = _connects(data, here, Vector2i(1, 0)) or _connects(data, here, Vector2i(-1, 0))
			var opens_z: bool = _connects(data, here, Vector2i(0, 1)) or _connects(data, here, Vector2i(0, -1))
			var junction: bool = opens_x and opens_z
			var mouth_dir: Vector2i = Vector2i.ZERO
			if kind == "e":
				for dir: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
					if _is_room(data.char_at(here + dir)):
						mouth_dir = dir
						break
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var along_x: bool = dir.y == 0
				var neighbour: String = data.char_at(here + dir)
				var offset: Vector3 = Vector3(dir.x, 0, dir.y) * (cell * 0.5)
				if _is_duct(neighbour):
					pass      # the tunnel carries on that way
				elif dir == mouth_dir:
					# This is a mouth: a grate across it, and the room on the other side. The
					# opening is exactly the size of the grate, with jambs filling the rest of
					# the cell, so there is no gap to see or shoot through round the edge of it.
					var grate := VentGrate.new()
					grate.along_x = not along_x
					entities.add_child(grate)
					grate.position = centre + offset * 0.92
					for jamb: float in [-1.0, 1.0]:
						var across := Vector3(0, 0, jamb) if along_x else Vector3(jamb, 0, 0)
						_slab(geometry, Vector3(GRATE_THICKNESS, HEIGHT, side) if along_x else Vector3(side, HEIGHT, GRATE_THICKNESS),
							centre + offset * 0.92 + across * (cell - side) * 0.5 + Vector3(0, HEIGHT * 0.5, 0))
					_slab(geometry, Vector3(cell, T.wall_height - HEIGHT, GRATE_THICKNESS) if not along_x else Vector3(GRATE_THICKNESS, T.wall_height - HEIGHT, cell),
						centre + offset * 0.92 + Vector3(0, HEIGHT + (T.wall_height - HEIGHT) * 0.5, 0))
				else:
					# Solid that way: cap the end of the tunnel. The cap is thin along the
					# direction it faces and as wide as the cell across it: the other way round
					# and it lies across the tunnel and seals it.
					_slab(geometry, Vector3(GRATE_THICKNESS, HEIGHT, cell) if along_x else Vector3(cell, HEIGHT, GRATE_THICKNESS),
						centre + offset - Vector3(dir.x, 0, dir.y) * GRATE_THICKNESS * 0.5 + Vector3(0, HEIGHT * 0.5, 0))
			if not junction:
				# A straight length: narrow it to `WIDTH` with a cheek down each side.
				for cheek: float in [-1.0, 1.0]:
					var across := Vector3(0, 0, cheek) if opens_x else Vector3(cheek, 0, 0)
					_slab(geometry, Vector3(cell if opens_x else side, HEIGHT, side if opens_x else cell),
						centre + across * (cell - side) * 0.5 + Vector3(0, HEIGHT * 0.5, 0))


static func _is_duct(cell_char: String) -> bool:
	return cell_char == "v" or cell_char == "e"


static func _is_room(cell_char: String) -> bool:
	return cell_char in ".~i"


## Is the tunnel open this way: another duct cell, or this cell's own grate?
static func _connects(data: LevelData, cell: Vector2i, dir: Vector2i) -> bool:
	var neighbour: String = data.char_at(cell + dir)
	if _is_duct(neighbour):
		return true
	if data.char_at(cell) != "e" or not _is_room(neighbour):
		return false
	# Only the first room side of a mouth is open; the rest of it stays wall.
	for way: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if _is_room(data.char_at(cell + way)):
			return way == dir
	return false


const T: Tuning = preload("res://data/tuning.tres")


static func _slab(parent: Node3D, size: Vector3, at: Vector3) -> void:
	# Everything that makes up a duct is sheet metal, inside and out.
	var body: StaticBody3D = LevelBuilder.make_box(size, Mats.duct_metal())
	body.name = "Duct"
	body.position = at
	parent.add_child(body)


## Is the tunnel open this way for something already inside it? Unlike `_connects`, a mouth
## counts as open from either side, because what is in there uses the grates as doors.
static func connects_for_lurker(data: LevelData, cell: Vector2i, dir: Vector2i) -> bool:
	return _is_duct(data.char_at(cell + dir))


## Is the tunnel open this way for something already inside it? A grate counts as a door here.
static func duct_that_way(data: LevelData, cell: Vector2i, dir: Vector2i) -> bool:
	return _is_duct(data.char_at(cell + dir))


## The mouth of a duct the player is looking at, within `reach`, or infinity if there is none.
## Returns the middle of the duct cell just inside it: where he ends up when he climbs in.
static func mouth_ahead(data: LevelData, from: Vector3, forward: Vector3, reach: float) -> Vector3:
	if data == null:
		return Vector3.INF
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.01:
		return Vector3.INF
	flat = flat.normalized()
	var best: Vector3 = Vector3.INF
	var best_distance: float = reach
	for y: int in data.height:
		for x: int in data.width:
			if data.rows[y][x] != "e":
				continue
			var centre: Vector3 = data.cell_center(Vector2i(x, y), 0.0)
			var to_mouth := Vector3(centre.x - from.x, 0.0, centre.z - from.z)
			var distance: float = to_mouth.length()
			if distance > best_distance or distance < 0.01:
				continue
			if flat.dot(to_mouth / distance) < 0.55:
				continue      # it has to be roughly what he is looking at
			best = Vector3(centre.x, 0.0, centre.z)
			best_distance = distance
	return best


## The nearest room cell next to this duct cell: where he comes out when he climbs out again.
static func room_beside(data: LevelData, at: Vector3) -> Vector3:
	var here: Vector2i = data.cell_of(at)
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_room(data.char_at(here + step)):
			return data.cell_center(here + step, 0.0)
	return Vector3.INF


## Is this world position inside a duct? The player crouches while it is.
static func inside(data: LevelData, at: Vector3) -> bool:
	if data == null:
		return false
	return _is_duct(data.char_at(data.cell_of(at)))
