extends "res://tests/test_case.gd"
## Every shipped floor must parse, build, bake, and be fully walkable.

const EXPECTED: Dictionary[String, Vector3i] = {
	# name: (width, height, enemies placed on the grid)
	"f1_lobby": Vector3i(20, 14, 4),
	# Every floor but the first also carries one to three gentlemen, from GENTLEMEN.
	"f2_offices": Vector3i(30, 22, 8),
	"f3_servers": Vector3i(28, 20, 9),
	"f4_labs": Vector3i(36, 24, 12),
	"f5_executive": Vector3i(40, 28, 13),
	"roof": Vector3i(30, 30, 4),
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


func test_every_floor_has_cover_and_spread_out_enemies() -> void:
	for floor_name: String in Game.FLOORS:
		var d: LevelData = LevelParser.load_level(floor_name)
		var pillars: int = 0
		for prop: Dictionary in d.props:
			if prop["kind"] == &"pillar":
				pillars += 1
		var cover: int = pillars
		for prop: Dictionary in d.props:
			cover += 1 if prop["kind"] == &"rack" or prop["kind"] == &"desk" else 0
		check(pillars >= 4 or cover >= 12, "%s has only %d pillars and %d cover pieces" % [floor_name, pillars, cover])
		for i: int in d.spawns.size():
			var a: Vector2i = d.spawns[i]["cell"]
			check(Vector2(a - d.player_start).length() >= 6.0, "%s: enemy at %s starts too close to the player" % [floor_name, a])
			for j: int in range(i + 1, d.spawns.size()):
				var b: Vector2i = d.spawns[j]["cell"]
				check(Vector2(a - b).length() >= 4.0, "%s: enemies at %s and %s start too close together" % [floor_name, a, b])
