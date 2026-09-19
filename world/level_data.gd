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


func initial_enemy_count() -> int:
	return spawns.size() + (1 if boss_cell.x >= 0 else 0)
