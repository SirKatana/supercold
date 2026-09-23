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
			if data.rows[y][x] != "v":
				continue
			var here := Vector2i(x, y)
			var centre: Vector3 = data.cell_center(here, 0.0)
			# The wall above the tunnel, so a duct still reads as a wall from the room.
			_slab(geometry, Vector3(cell, T.wall_height - HEIGHT, cell),
				centre + Vector3(0, HEIGHT + (T.wall_height - HEIGHT) * 0.5, 0))
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var along_x: bool = dir.y == 0
				var neighbour: String = data.char_at(here + dir)
				if neighbour == "v":
					continue      # the duct carries on that way
				var offset: Vector3 = Vector3(dir.x, 0, dir.y) * (cell * 0.5)
				if neighbour in ".~iP X":
					# It opens into a room here: a grate across the mouth.
					var grate := VentGrate.new()
					grate.along_x = not along_x
					entities.add_child(grate)
					grate.position = centre + offset * 0.92
				else:
					# Solid that way: close the end of the tunnel.
					_slab(geometry, Vector3(cell if along_x else GRATE_THICKNESS, HEIGHT, GRATE_THICKNESS if along_x else cell),
						centre + offset + Vector3(0, HEIGHT * 0.5, 0) - Vector3(dir.x, 0, dir.y) * GRATE_THICKNESS * 0.5)
				# The cheeks either side of the opening, so the tunnel is only `WIDTH` wide.
				for cheek: float in [-1.0, 1.0]:
					var across := Vector3(0, 0, cheek) if along_x else Vector3(cheek, 0, 0)
					_slab(geometry, Vector3(side if along_x else cell, HEIGHT, cell if along_x else side),
						centre + across * (cell - side) * 0.5 + Vector3(0, HEIGHT * 0.5, 0))


const T: Tuning = preload("res://data/tuning.tres")


static func _slab(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body: StaticBody3D = LevelBuilder.make_box(size, LevelBuilder.wall_material)
	body.name = "Duct"
	body.position = at
	parent.add_child(body)


## Is this world position inside a duct? The player crouches while it is.
static func inside(data: LevelData, at: Vector3) -> bool:
	if data == null:
		return false
	return data.char_at(data.cell_of(at)) == "v"
