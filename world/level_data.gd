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


func initial_enemy_count() -> int:
	return spawns.size() + (1 if boss_cell.x >= 0 else 0)
