extends "res://tests/test_case.gd"


func before_each() -> void:
	TimeManager.override_scale = 1.0
	AdService.auto_result = 1
	HelperVoice.tts_enabled = false
	Game.god_mode = true
	Game.start_run_state_for_tests()


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.start_run_state_for_tests()
	Game.unload_level()


func _facing(yaw_deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3.ZERO)


func test_clock_directions() -> void:
	var me: Transform3D = _facing(0.0)      # looking down -Z
	check_eq(HelperVoice.clock_direction(me, Vector3(0, 0, -10)), 12, "dead ahead")
	check_eq(HelperVoice.clock_direction(me, Vector3(10, 0, 0)), 3, "to the right")
	check_eq(HelperVoice.clock_direction(me, Vector3(0, 0, 10)), 6, "behind")
	check_eq(HelperVoice.clock_direction(me, Vector3(-10, 0, 0)), 9, "to the left")
	check_eq(HelperVoice.clock_direction(me, Vector3(5.77, 0, -10)), 1, "one o'clock")
	# Turn the listener to face +X and the same point moves round the dial.
	check_eq(HelperVoice.clock_direction(_facing(-90.0), Vector3(10, 0, 0)), 12, "now it is ahead")
	check_eq(HelperVoice.clock_direction(_facing(-90.0), Vector3(0, 0, -10)), 9, "and old ahead is on the left")


func test_sector_names() -> void:
	var d: LevelData = LevelParser.load_level("f5_executive")
	check_eq(HelperVoice.sector(d, Vector3(1, 0, 1)), "A1", "top left")
	check_eq(HelperVoice.sector(d, Vector3(9, 0, 1)), "B1", "one sector east")
	check_eq(HelperVoice.sector(d, Vector3(1, 0, 17)), "A3", "two sectors south")


func test_greeting_is_what_was_asked_for() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var helper: Helper = Game.hire_helper(Game.data.cell_center(Vector2i(6, 8), 0.05), Basis.IDENTITY)
	check_eq(helper.voice.last_line, "Hey! I'm your helper for three minutes!", "the greeting")
	check(helper.voice.is_talking(), "bubble is up")
	check(helper.voice._label.visible and helper.voice._panel.visible, "text on a white panel")
	check_eq(helper.voice._label.text, helper.voice.last_line, "bubble shows the line")


func test_callout_names_the_enemy_gives_clock_distance_and_sector() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var dude: PinkDude = Game.spawn_dude(Vector3(20, 0.05, 6), true, &"rifle")
	var line: String = HelperVoice.callout(Transform3D(Basis.IDENTITY, Vector3(10, 0, 6)), dude, Game.data)
	check_eq(line, "Rifleman, 3 o'clock, 10 metres, sector C1!", "rifleman to the right")
	var trooper: PinkDude = Game.spawn_dude(Vector3(10, 0.05, 0), true, &"shield")
	var second: String = HelperVoice.callout(Transform3D(Basis.IDENTITY, Vector3(10, 0, 6)), trooper, Game.data)
	check(second.begins_with("Shield trooper, 12 o'clock, 6 metres"), second)
	check(second.ends_with("Aim for the glass!"), "and the tip that matters")


func test_helper_calls_out_a_dude_once() -> void:
	check(Game.load_level("test_room"), "level loads")
	await LevelValidator.wait_until_synced(Game.level, Game.data)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	for node: Node in get_tree().get_nodes_in_group(&"barrels"):
		node.free()
	Game.alive_enemies = 0
	var spot: Vector3 = Game.data.cell_center(Vector2i(5, 8), 0.05)
	var helper: Helper = Game.hire_helper(spot, Basis.IDENTITY)
	helper.voice.shut_up()
	helper.voice._current_priority = -1
	var dude: PinkDude = Game.spawn_dude(spot + Vector3(9, 0, 0), true)
	dude.sense_override = true
	dude.set_physics_process(false)
	Game.player.global_position = spot + Vector3(0, 0, -4)
	await wait_physics(30)
	var callouts: int = 0
	for line: String in helper.voice.history:
		if line.contains("o'clock"):
			callouts += 1
	check_eq(callouts, 1, "one callout for one dude: %s" % ", ".join(helper.voice.history))
	check(helper.voice.history[helper.voice.history.size() - 1].contains("metres") or helper.kills > 0, "with a distance in it")


func test_he_complains_when_shot_but_not_every_time() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var helper: Helper = Game.hire_helper(Game.data.cell_center(Vector2i(6, 8), 0.05), Basis.IDENTITY)
	helper.set_physics_process(false)
	helper.voice.shut_up()
	helper.voice._current_priority = -1
	var before: int = helper.voice.history.size()
	for i: int in 5:
		helper.on_bullet_hit(null, helper.global_position + Vector3.UP, Vector3.LEFT)
	check_eq(helper.voice.history.size(), before + 1, "five hits in a row, one complaint")
	var hit_texts: Array[String] = []
	for id: StringName in Helper.HIT_LINES:
		hit_texts.append(HelperVoice.line(id))
	check(hit_texts.has(helper.voice.last_line), "and it is one of his hit lines: %s" % helper.voice.last_line)
	check(helper._flinch > 0.5, "he flinches too")


func test_priorities_stop_him_talking_over_himself() -> void:
	var voice := HelperVoice.new()
	add_child(voice)
	check(voice.say("Important thing.", HelperVoice.Priority.IMPORTANT), "important line goes out")
	check(not voice.say("Chatter.", HelperVoice.Priority.CHATTER), "chatter waits")
	check(not voice.say("Callout.", HelperVoice.Priority.CALLOUT), "so does a callout")
	check_eq(voice.last_line, "Important thing.", "still the important one")
	check(voice.say("Even more important.", HelperVoice.Priority.IMPORTANT) == false, "same priority does not interrupt")
	voice.free()


func test_bubble_goes_away_and_then_he_pauses() -> void:
	var voice := HelperVoice.new()
	add_child(voice)
	voice.say("Short.", HelperVoice.Priority.CALLOUT)
	check(voice.is_talking(), "talking")
	await wait_frames(130)
	check(not voice.is_talking(), "bubble closed after about two seconds")
	check(not voice._label.visible, "and hidden")
	check(not voice.say("Chatter right away.", HelperVoice.Priority.CHATTER), "no chatter straight after")
	check(voice.say("But a callout is fine.", HelperVoice.Priority.CALLOUT), "callouts are not held back")
	voice.free()


func test_goodbye_lines() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(2)
	var helper: Helper = Game.hire_helper(Game.data.cell_center(Vector2i(2, 2), 0.05), Basis.IDENTITY)
	helper.set_physics_process(false)
	helper.voice.shut_up()
	helper.voice._current_priority = -1
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	await wait_physics(2)
	check_eq(helper.voice.last_line, "Floor clear! My work here is done.", "goodbye on a cleared floor")


func test_tts_is_available_on_a_machine_with_a_voice() -> void:
	# Headless has no TTS. This only checks the project setting that turns it on in the real game.
	check(ProjectSettings.get_setting("audio/general/text_to_speech", false), "text to speech is enabled in project settings")


func test_every_line_has_a_recorded_clip() -> void:
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://allies/voice_lines.json"))
	check(lines.size() > 90, "the line list is loaded (%d)" % lines.size())
	var missing: PackedStringArray = []
	for id: String in lines:
		if HelperVoice.clip(StringName(id)) == null:
			missing.append(id)
	check(missing.is_empty(), "lines with no clip: %s" % ", ".join(missing))


func test_every_id_the_helper_uses_exists() -> void:
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://allies/voice_lines.json"))
	var regex := RegEx.new()
	regex.compile('&"([a-z_0-9]+)"')
	var source: String = FileAccess.get_file_as_string("res://allies/helper.gd")
	for m: RegExMatch in regex.search_all(source):
		var id: String = m.get_string(1)
		if id.begins_with("hit_") or id.begins_with("kill_") or id.begins_with("blocked_") or id.begins_with("quiet_") \
				or id.begins_with("bye_") or id.begins_with("greet") or id.ends_with("_tip") or id in ["minute_left", "ten_seconds", "count_many"]:
			check(lines.has(id), "helper.gd uses line '%s' which is not in voice_lines.json" % id)


func test_callout_is_spoken_from_clips() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(2)
	var dude: PinkDude = Game.spawn_dude(Vector3(20, 0.05, 6), true, &"rifle")
	var ids: Array[StringName] = HelperVoice.callout_clips(Transform3D(Basis.IDENTITY, Vector3(10, 0, 6)), dude)
	check_eq(ids, [&"name_rifle", &"clock_3", &"dist_10"] as Array[StringName], "who, which way, how far")
	for id: StringName in ids:
		check(HelperVoice.clip(id) != null, "clip %s exists" % id)
