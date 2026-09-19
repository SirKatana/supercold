extends Node
## Floor flow and run state.

signal floor_loaded(data: LevelData)

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

var level_root: Node3D
var level: Node3D
var data: LevelData
var player: Player


func _ensure_root() -> void:
	if level_root == null or not is_instance_valid(level_root):
		level_root = Node3D.new()
		level_root.name = "LevelRoot"
		get_tree().root.add_child(level_root)


func unload_level() -> void:
	if level != null and is_instance_valid(level):
		level.free()
	level = null
	player = null


func load_level(level_name: String) -> bool:
	_ensure_root()
	unload_level()
	data = LevelParser.load_level(level_name)
	if not data.errors.is_empty():
		for e: String in data.errors:
			push_error("level %s: %s" % [level_name, e])
		return false
	level = LevelBuilder.build(data)
	level_root.add_child(level)

	player = PLAYER_SCENE.instantiate()
	level.add_child(player)
	player.global_position = data.cell_center(data.player_start, 0.05)
	var centre := Vector3(data.width * data.cell_size * 0.5, 0.05, data.height * data.cell_size * 0.5)
	if centre.distance_to(player.global_position) > 0.5:
		player.look_at(Vector3(centre.x, player.global_position.y, centre.z))
	TimeManager.reset()
	floor_loaded.emit(data)
	return true
