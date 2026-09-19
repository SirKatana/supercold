extends "res://tests/test_case.gd"
## Every shipped floor must parse, build, bake, and be fully walkable.

const EXPECTED: Dictionary[String, Vector3i] = {
	# name: (width, height, enemies placed on the grid)
	"f1_lobby": Vector3i(20, 14, 4),
	"f2_offices": Vector3i(30, 22, 7),
	"f3_servers": Vector3i(28, 20, 8),
	"f4_labs": Vector3i(36, 24, 10),
	"f5_executive": Vector3i(40, 28, 12),
	"roof": Vector3i(30, 30, 2),
}


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_floor_list_files_exist() -> void:
	for floor_name: String in Game.FLOORS:
		check(FileAccess.file_exists("res://levels/%s.txt" % floor_name), "%s.txt missing" % floor_name)


func test_floor_sizes_and_enemy_counts_match_the_plan() -> void:
	for floor_name: String in EXPECTED:
		var d: LevelData = LevelParser.load_level(floor_name)
		check(d.errors.is_empty(), "%s: %s" % [floor_name, ", ".join(d.errors)])
		var want: Vector3i = EXPECTED[floor_name]
		check_eq(Vector2i(d.width, d.height), Vector2i(want.x, want.y), "%s size" % floor_name)
		check_eq(d.spawns.size(), want.z, "%s enemies" % floor_name)


func test_every_floor_loads_and_is_walkable() -> void:
	for floor_name: String in Game.FLOORS:
		if not FileAccess.file_exists("res://levels/%s.txt" % floor_name):
			continue
		check(Game.load_level(floor_name), "%s loads" % floor_name)
		check(await LevelValidator.wait_until_synced(Game.level, Game.data), "%s nav synced" % floor_name)
		var problems: PackedStringArray = LevelValidator.unreachable(Game.level, Game.data)
		check(problems.is_empty(), "%s: %s" % [floor_name, "; ".join(problems)])
		check_eq(Game.alive_enemies, Game.data.initial_enemy_count(), "%s spawned everyone" % floor_name)


func test_floors_advance_in_order() -> void:
	check(Game.load_floor(0), "first floor loads")
	check_eq(Game.level_name, "f1_lobby", "starts in the lobby")
	Game.next_floor()
	check_eq(Game.level_name, "f2_offices", "then offices")
