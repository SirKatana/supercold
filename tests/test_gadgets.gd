extends "res://tests/test_case.gd"
## Fart grenades, freeze bombs and water buckets are handed out unevenly across the thirty
## floors, and on a floor that has them they are spread round the map.

const KINDS: Array[StringName] = [&"fart", &"freeze", &"bucket"]


func _gadgets(d: LevelData) -> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {&"fart": [], &"freeze": [], &"bucket": []}
	for p: Dictionary in d.pickups:
		if out.has(p["kind"]):
			out[p["kind"]].append(p["cell"])
	return out


func test_distribution_is_uneven_on_purpose() -> void:
	var floors_with: Dictionary[StringName, int] = {&"fart": 0, &"freeze": 0, &"bucket": 0}
	var none: PackedStringArray = []
	var all_three: PackedStringArray = []
	var one_kind: int = 0
	var two_kinds: int = 0
	for floor_name: String in Game.FLOORS:
		var g: Dictionary[StringName, Array] = _gadgets(LevelParser.load_level(floor_name))
		var kinds_here: int = 0
		for kind: StringName in KINDS:
			if not g[kind].is_empty():
				kinds_here += 1
				floors_with[kind] += 1
		match kinds_here:
			0: none.append(floor_name)
			1: one_kind += 1
			2: two_kinds += 1
			3: all_three.append(floor_name)
	var total: int = Game.FLOORS.size()
	check(none.size() >= 5 and none.size() <= total / 3, "%d floors have none of the three: %s" % [none.size(), ", ".join(none)])
	check(all_three.size() >= 1 and all_three.size() <= 4, "only a couple have all three: %s" % ", ".join(all_three))
	check(one_kind >= 8, "plenty have just one kind (%d)" % one_kind)
	check(two_kinds >= 5, "and some have two (%d)" % two_kinds)
	for kind: StringName in KINDS:
		check(floors_with[kind] >= 8 and floors_with[kind] <= total / 2,
			"%s is on %d of %d floors" % [kind, floors_with[kind], total])


func test_gadgets_are_spread_round_the_map_not_piled_at_the_lift() -> void:
	for floor_name: String in Game.FLOORS:
		var d: LevelData = LevelParser.load_level(floor_name)
		var g: Dictionary[StringName, Array] = _gadgets(d)
		var cells: Array[Vector2i] = []
		for kind: StringName in KINDS:
			for cell: Vector2i in g[kind]:
				cells.append(cell)
		for i: int in cells.size():
			check(Vector2(cells[i] - d.player_start).length() >= 6.0,
				"%s: a gadget at %s is handed to you at the lift" % [floor_name, cells[i]])
			for j: int in range(i + 1, cells.size()):
				check(Vector2(cells[i] - cells[j]).length() >= 4.0,
					"%s: gadgets at %s and %s are piled together" % [floor_name, cells[i], cells[j]])
		if cells.size() >= 4:
			# They should reach across the floor, not sit in one corner of it.
			var low := Vector2(INF, INF)
			var high := Vector2(-INF, -INF)
			for cell: Vector2i in cells:
				low = low.min(Vector2(cell))
				high = high.max(Vector2(cell))
			var covered: float = (high.x - low.x) / d.width
			check(covered >= 0.35, "%s: gadgets only cover %.0f%% of the floor's width" % [floor_name, covered * 100.0])


func test_the_floors_you_would_expect_still_have_their_gadget() -> void:
	check(_gadgets(LevelParser.load_level("f15_restrooms"))[&"fart"].size() >= 3, "restrooms have stink grenades")
	check(_gadgets(LevelParser.load_level("f18_beanworks"))[&"fart"].size() >= 4, "so does the bean cannery")
	check(_gadgets(LevelParser.load_level("f22_cryolab"))[&"freeze"].size() >= 4, "cryo lab has freeze bombs")
	check(_gadgets(LevelParser.load_level("f28_waterworks"))[&"bucket"].size() >= 3, "waterworks has buckets")
	check(_gadgets(LevelParser.load_level("f2_offices"))[&"fart"].is_empty(), "and the offices have nothing")
