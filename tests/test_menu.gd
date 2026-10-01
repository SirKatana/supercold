extends "res://tests/test_case.gd"
## The main menu: the room behind it, and the buttons in front of it.


func test_the_stage_builds_a_capsule_an_agent_and_a_mob() -> void:
	var stage := TitleStage.new()
	add_child(stage)
	await wait_physics(2)
	var figures: int = 0
	for node: Node in stage.get_children():
		if node is Humanoid:
			figures += 1
	# One in the capsule, three outside hammering on it.
	check_eq(figures, 4, "four people in the room")
	var cameras: int = 0
	for node: Node in stage.get_children():
		if node is Camera3D:
			cameras += 1
	check_eq(cameras, 1, "it brings its own camera, there is no player at the title")
	stage.queue_free()


func test_the_mob_stands_clear_of_the_glass() -> void:
	var stage := TitleStage.new()
	add_child(stage)
	await wait_physics(2)
	for node: Node in stage.get_children():
		if not (node is Humanoid):
			continue
		var flat: Vector2 = Vector2(node.global_position.x - TitleStage.CAPSULE.x,
			node.global_position.z - TitleStage.CAPSULE.z)
		# Either the man inside it, or well outside it. Nobody half way through the glass.
		check(flat.length() < 0.2 or flat.length() > TitleStage.RADIUS + 0.3,
			"a figure stands at %.2f m from the middle" % flat.length())
	stage.queue_free()


func test_the_menu_offers_play_settings_and_exit() -> void:
	var menu := TitleScreen.new()
	add_child(menu)
	await wait_physics(2)
	var captions: PackedStringArray = []
	for button: Node in _buttons_of(menu):
		captions.append((button as Button).text)
	var joined: String = " | ".join(captions)
	check("PLAY" in joined or "CONTINUE" in joined, "somewhere to start: %s" % joined)
	check("SETTINGS" in joined, "and settings: %s" % joined)
	check("EXIT" in joined, "and a way out: %s" % joined)
	menu.queue_free()


func test_settings_swaps_for_the_buttons_and_back() -> void:
	var menu := TitleScreen.new()
	add_child(menu)
	await wait_physics(2)
	var panel: SettingsPanel = null
	for node: Node in _all_under(menu):
		if node is SettingsPanel:
			panel = node
	check(panel != null, "the settings panel is built with the menu")
	check(not panel.get_parent().visible, "and hidden until it is asked for")
	menu._show_settings(true)
	check(panel.get_parent().visible, "SETTINGS shows it")
	menu._show_settings(false)
	check(not panel.get_parent().visible, "BACK puts it away")
	menu.queue_free()


func _buttons_of(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in _all_under(root):
		if node is Button:
			found.append(node)
	return found


func _all_under(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in root.get_children():
		found.append(child)
		found.append_array(_all_under(child))
	return found
