extends "res://tests/test_case.gd"
## Windows in the outer wall, and what goes through them.

const FLOORS_WITH_WINDOWS: PackedStringArray = ["f10_vault", "f11_sewers", "f12_kitchen",
	"f14_glassworks", "f15_restrooms"]


func before_each() -> void:
	Game.god_mode = true


func after_each() -> void:
	Game.god_mode = false
	Game.unload_level()


func test_ten_to_fifteen_have_windows_and_the_basement_does_not() -> void:
	for floor_name: String in FLOORS_WITH_WINDOWS:
		var d: LevelData = LevelParser.load_level(floor_name)
		check(d.errors.is_empty(), "%s parses: %s" % [floor_name, ", ".join(d.errors)])
		# Three is what the stricter rule leaves on the tighter layouts: a window has to have
		# real air behind it, and not every outside wall does.
		check(d.windows.size() >= 3, "%s has windows (%d)" % [floor_name, d.windows.size()])
	# 13 is the sub-basement. There is nothing outside it to fall into.
	check_eq(LevelParser.load_level("f13_basement").windows.size(), 0, "no windows underground")
	check_eq(LevelParser.load_level("f1_lobby").windows.size(), 0, "and none on the ground floor")


func test_a_window_is_still_a_wall_until_it_breaks() -> void:
	var d: LevelData = LevelParser.load_level("f12_kitchen")
	var cell: Vector2i = d.windows[0]["cell"]
	check(d.is_solid(cell), "nobody walks through the glass")
	check(not d.is_open(cell), "and the navmesh does not run through it")


func test_breaking_one_leaves_a_hole_and_says_so() -> void:
	check(Game.load_level("f12_kitchen"), "kitchen loads")
	await wait_physics(2)
	var panes: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(&"windows"):
		panes.append(node)
	check(panes.size() >= 3, "the windows are built (%d)" % panes.size())
	var told: Dictionary = {"count": 0}
	var on_broken: Callable = func(_at: Vector3) -> void: told["count"] += 1
	Game.window_broken.connect(on_broken)
	(panes[0] as GlassPane).take_damage(9, Vector3.FORWARD)
	check_eq(told["count"], 1, "breaking one is announced")
	Game.window_broken.disconnect(on_broken)


func test_a_punch_only_throws_him_when_there_is_a_window_to_throw_him_through() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(2.0, 0.0, 0.0)
	await wait_physics(2)
	dude.sense_override = true
	# An ordinary punch leaves him on his feet: knocking everybody across the room was wrong.
	dude.on_punched(Game.player, dude.global_position)
	check(not dude.flung, "an ordinary punch does not launch him")
	check(not dude.has_weapon(), "but it does take his gun off him")
	# Now put a hole in the wall behind him and try again.
	Game.open_windows.append(dude.global_position + Vector3(1.6, 0.0, 0.0))
	dude.on_punched(Game.player, dude.global_position)
	check(dude.flung, "with a window there, out he goes")
	Game.open_windows.clear()
	dude.queue_free()


func test_a_long_enough_fall_kills_whoever_is_in_it() -> void:
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(3.0, 0.0, 0.0)
	await wait_physics(2)
	dude.sense_override = true
	dude.shove(Vector3(0, -1.0, 0))
	dude.global_position = Vector3(dude.global_position.x, T.fall_death_y - 1.0, dude.global_position.z)
	await wait_physics(3)
	# Dying swaps him for a ragdoll, so the node itself may already be gone.
	check(not is_instance_valid(dude) or not dude.alive, "down the side of the building")
