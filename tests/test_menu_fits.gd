extends "res://tests/test_case.gd"
## Every button on the menu has to be on the screen. The LAN panel's BACK was off the bottom.


func _buttons(root: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in root.get_children():
		if child is Button:
			found.append(child)
		found.append_array(_buttons(child))
	return found


func _check_panel_fits(menu: TitleScreen, what: String) -> void:
	var height: float = menu.get_viewport().get_visible_rect().size.y
	for button: Button in _buttons(menu):
		if not button.is_visible_in_tree():
			continue
		var bottom: float = button.global_position.y + button.size.y
		check(bottom <= height, "%s: %s ends at %.0f of %.0f" % [what, button.text, bottom, height])


func test_the_lan_panel_fits_on_the_screen() -> void:
	var menu := TitleScreen.new()
	add_child(menu)
	await wait_frames(3)
	menu._show_lan(true)
	await wait_frames(3)
	var seen: PackedStringArray = []
	for button: Button in _buttons(menu):
		if button.is_visible_in_tree():
			seen.append(button.text)
	check(seen.has("BACK"), "there is a way out of it: %s" % ", ".join(seen))
	_check_panel_fits(menu, "LAN")
	menu.queue_free()


func test_the_settings_panel_fits_too() -> void:
	var menu := TitleScreen.new()
	add_child(menu)
	await wait_frames(3)
	menu._show_settings(true)
	await wait_frames(3)
	_check_panel_fits(menu, "settings")
	menu.queue_free()


func test_back_puts_the_menu_and_the_words_back() -> void:
	var menu := TitleScreen.new()
	add_child(menu)
	await wait_frames(3)
	menu._show_lan(true)
	await wait_frames(2)
	check(not menu._menu.visible, "the menu stands down")
	menu._show_lan(false)
	await wait_frames(2)
	check(menu._menu.visible, "and comes back")
	for row: Label in menu._titles:
		check(row.visible, "the big words come back too")
	menu.queue_free()
