class_name LevelData
extends RefCounted
## Parsed floor. Cells are (column, row); world position comes from cell_center().

var level_name: String = ""
var width: int = 0
var height: int = 0
var rows: PackedStringArray = []
var errors: PackedStringArray = []

var player_start: Vector2i = Vector2i(-1, -1)
var exit_cell: Vector2i = Vector2i(-1, -1)
var boss_cell: Vector2i = Vector2i(-1, -1)
## {cell: Vector2i, armed: bool}
var spawns: Array[Dictionary] = []
## {cell: Vector2i, kind: StringName}
var pickups: Array[Dictionary] = []
## {cell: Vector2i, along_x: bool}
var doors: Array[Dictionary] = []
var glass: Array[Dictionary] = []
## {cell: Vector2i, kind: StringName}
var props: Array[Dictionary] = []
var wave_points: Array[Vector2i] = []
## {cell: Vector2i, icy: bool}
var puddles: Array[Dictionary] = []
var fart_cells: Array[Vector2i] = []
## Cells of deep pool. The floor is cut away under them.
var deep_cells: Array[Vector2i] = []
## &"director", &"brute" or &"warden"
var boss_kind: StringName = &"director"
## Colours and light for this floor. Keys: wall, floor, prop, ambient, sky, light.
var theme: Dictionary = {}
var title: String = ""
var triggers: Array[Vector2i] = []

var intro: String = ""
var open_sky: bool = false
## &"elevator" or &"helipad"
var exit_kind: StringName = &"elevator"
## {after_kills: int, on_trigger: bool, count: int, armed: int}
var waves: Array[Dictionary] = []

var cell_size: float = 2.0


func cell_center(cell: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size, y, (cell.y + 0.5) * cell_size)


func char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= height or cell.x < 0 or cell.x >= width:
		return " "
	return rows[cell.y][cell.x]


func is_solid(cell: Vector2i) -> bool:
	var c: String = char_at(cell)
	return c == "#" or c == " "


func is_open(cell: Vector2i) -> bool:
	return not "# cso".contains(char_at(cell))


## Which way an elevator in this cell faces: toward open floor with a wall at its back if it can,
## otherwise toward whichever open neighbour points most at the middle of the level.
func door_direction(cell: Vector2i) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for dir: Vector2i in dirs:
		if is_open(cell + dir) and is_solid(cell - dir):
			return dir
	var to_centre := Vector2(width * 0.5 - cell.x, height * 0.5 - cell.y)
	var best: Vector2i = Vector2i.DOWN
	var best_dot: float = -INF
	for dir: Vector2i in dirs:
		if is_open(cell + dir) and Vector2(dir).dot(to_centre) > best_dot:
			best_dot = Vector2(dir).dot(to_centre)
			best = dir
	return best


## The floor cell just outside an elevator's doors.
func front_cell(cell: Vector2i) -> Vector2i:
	return cell + door_direction(cell)


## A plain floor cell near the arrival lift for the helper capsule: beside the path out of the
## doors, never in it. Returns (-1, -1) if the lift opens onto something cramped.
func capsule_cell() -> Vector2i:
	var dir: Vector2i = door_direction(player_start)
	var side := Vector2i(dir.y, -dir.x)
	var front: Vector2i = front_cell(player_start)
	var offsets: Array[Vector2i] = []
	for along: int in [1, 2, 3, 4, 5]:
		offsets.append(dir * along + side)
		offsets.append(dir * along - side)
	offsets.append(side)
	offsets.append(-side)
	for offset: Vector2i in offsets:
		var cell: Vector2i = front + offset
		# Plain, wet or icy floor will do. Never beside a door: the capsule is wide enough to block one.
		if not ".~i".contains(char_at(cell)):
			continue
		var by_a_door: bool = false
		for dy: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				if char_at(cell + Vector2i(dx, dy)) == "D":
					by_a_door = true
		if not by_a_door:
			return cell
	return Vector2i(-1, -1)


## Buried biters do not count until they climb out.
func initial_enemy_count() -> int:
	var count: int = 1 if boss_cell.x >= 0 else 0
	for spawn: Dictionary in spawns:
		if spawn.get("weapon", &"pistol") != &"zombie":
			count += 1
	return count
