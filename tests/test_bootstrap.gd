extends "res://tests/test_case.gd"


func test_autoloads_exist() -> void:
	check(get_node_or_null("/root/TimeManager") != null, "TimeManager autoload missing")
	check(get_node_or_null("/root/Game") != null, "Game autoload missing")
	check(get_node_or_null("/root/Settings") != null, "Settings autoload missing")
	check(get_node_or_null("/root/Sfx") != null, "Sfx autoload missing")


func test_input_actions_exist() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump",
			&"primary", &"secondary", &"interact", &"restart", &"pause"]:
		check(InputMap.has_action(action), "missing input action %s" % action)
