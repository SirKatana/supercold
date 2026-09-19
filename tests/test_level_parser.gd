extends "res://tests/test_case.gd"


func test_parses_basic_grid() -> void:
	var d: LevelData = LevelParser.parse("#####\n#P.X#\n#####\n")
	check(d.errors.is_empty(), "no errors expected: %s" % ", ".join(d.errors))
	check_eq(d.width, 5, "width")
	check_eq(d.height, 3, "height")
	check_eq(d.player_start, Vector2i(1, 1), "player start")
	check_eq(d.exit_cell, Vector2i(3, 1), "exit")


func test_reports_missing_start_and_exit() -> void:
	var d: LevelData = LevelParser.parse("###\n#.#\n###")
	check_eq(d.errors.size(), 2, "two errors")


func test_reports_unknown_character() -> void:
	var d: LevelData = LevelParser.parse("#P?X#")
	check(d.errors.size() == 1 and d.errors[0].contains("unknown"), "unknown char error")


func test_entities_and_sidecar() -> void:
	var grid: String = "#######\n#P.a.u#\n#pbmkl#\n#csw.X#\n#######"
	var json: String = '{"intro":"HI","waves":[{"after_kills":2,"count":3,"armed":1}]}'
	var d: LevelData = LevelParser.parse(grid, json)
	check(d.errors.is_empty(), "no errors expected: %s" % ", ".join(d.errors))
	check_eq(d.spawns.size(), 2, "spawns")
	check_eq(d.spawns[0]["armed"], true, "first is armed")
	check_eq(d.spawns[1]["armed"], false, "second is unarmed")
	check_eq(d.pickups.size(), 5, "pickups")
	check_eq(d.props.size(), 2, "props")
	check_eq(d.wave_points.size(), 1, "wave points")
	check_eq(d.intro, "HI", "intro")
	check_eq(d.waves.size(), 1, "waves")
	check_eq(d.waves[0]["after_kills"], 2, "wave trigger")


func test_door_orientation() -> void:
	var d: LevelData = LevelParser.parse("#####\n#P#X#\n##D##\n#...#\n#####")
	check_eq(d.doors.size(), 1, "one door")
	check_eq(d.doors[0]["along_x"], true, "door between left and right walls spans x")
	var d2: LevelData = LevelParser.parse("#####\n#P#.#\n#.D.#\n#.#X#\n#####")
	check_eq(d2.doors[0]["along_x"], false, "door between upper and lower walls spans z")


func test_ragged_rows_are_padded() -> void:
	var d: LevelData = LevelParser.parse("#####\n#PX#\n#####")
	check_eq(d.rows[1].length(), 5, "padded row")


func test_wall_rects_merge() -> void:
	var d: LevelData = LevelParser.parse("####\n#PX#\n####")
	var rects: Array[Rect2i] = LevelBuilder.wall_rects(d)
	check_eq(rects.size(), 4, "top, bottom, two sides")
	var cells: int = 0
	for r: Rect2i in rects:
		cells += r.size.x * r.size.y
	check_eq(cells, 10, "every wall cell covered once")


func test_cell_center() -> void:
	var d: LevelData = LevelParser.parse("#P.X#")
	check_eq(d.cell_center(Vector2i(1, 0)), Vector3(3.0, 0.0, 1.0), "cell centre at 2 m cells")
