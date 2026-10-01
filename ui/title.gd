class_name TitleScreen
extends CanvasLayer
## The main menu. The words sit on the left; behind them is `TitleStage`, the white room with
## the agent turning in his glass capsule and three pink dudes hammering on it.
##
## PLAY picks up where the last run left off. SETTINGS swaps the buttons for the sliders.
## EXIT quits.

signal start_requested(from_floor: int)

var _stage: TitleStage
var _menu: VBoxContainer
var _settings: VBoxContainer
var _play: Button
var _fresh: Button
var _lan: VBoxContainer
var _code_label: Label
var _code_entry: LineEdit
var _lan_note: Label


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS

	# A soft wash down the left so the words stay readable over whatever the room is doing.
	var wash := ColorRect.new()
	wash.color = Color(0.95, 0.96, 0.98, 0.86)
	wash.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	wash.offset_right = 540
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 64
	column.offset_right = 500
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 12)
	add_child(column)

	column.add_child(_label("SUPER", 112, Color(0.04, 0.04, 0.05)))
	column.add_child(_label("COLD", 112, Mats.PINK))
	column.add_child(_label("TIME CRAWLS WHEN YOU STAND STILL", 20, Color(0.04, 0.04, 0.05)))
	column.add_child(_label("", 14, Color.BLACK))

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 12)
	column.add_child(_menu)
	_play = _button(_menu, "PLAY", func() -> void: start_requested.emit(Game.best_floor))
	_fresh = _button(_menu, "NEW GAME", func() -> void:
		Game.erase_progress()
		start_requested.emit(0))
	_button(_menu, "PLAY TOGETHER", func() -> void: _show_lan(true))
	_button(_menu, "SETTINGS", func() -> void: _show_settings(true))
	_button(_menu, "EXIT", func() -> void: get_tree().quit())

	_lan = VBoxContainer.new()
	_lan.add_theme_constant_override(&"separation", 10)
	_lan.visible = false
	column.add_child(_lan)
	_build_lan()

	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override(&"separation", 12)
	_settings.visible = false
	column.add_child(_settings)
	_settings.add_child(SettingsPanel.new())
	_button(_settings, "BACK", func() -> void: _show_settings(false))

	column.add_child(_label("", 14, Color.BLACK))
	column.add_child(_label("WASD move   MOUSE look   LMB punch / shoot   RMB grab / throw\nE swap   Q throw   F shield   R restart   ESC pause",
		14, Color(0.3, 0.32, 0.36)))

	visibility_changed.connect(_refresh)
	_refresh()


## The room behind the menu. Main hands it in, because the stage is 3D and this is a layer.
func use_stage(stage: TitleStage) -> void:
	_stage = stage
	_refresh()


func _show_settings(on: bool) -> void:
	_menu.visible = not on
	_settings.visible = on
	if on:
		_lan.visible = false


## The LAN panel: host and read the code out, or type one in and join.
func _show_lan(on: bool) -> void:
	_menu.visible = not on
	_lan.visible = on
	if on:
		_settings.visible = false
		_refresh_lan()


func _build_lan() -> void:
	_lan.add_child(_label("SAME WIFI ONLY", 20, Color(0.3, 0.32, 0.36)))
	_code_label = _label("", 40, Mats.PINK)
	_lan.add_child(_code_label)
	_lan_note = _label("", 16, Color(0.3, 0.32, 0.36))
	_lan.add_child(_lan_note)
	_button(_lan, "HOST A GAME", func() -> void:
		var given: String = Net.host()
		if given != "":
			_lan_note.text = "READ THIS OUT. THEY TYPE IT IN."
		_refresh_lan())
	_code_entry = LineEdit.new()
	_code_entry.placeholder_text = "CODE"
	_code_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_entry.max_length = 8
	_code_entry.custom_minimum_size = Vector2(300, 44)
	_code_entry.add_theme_font_size_override(&"font_size", 24)
	_lan.add_child(_code_entry)
	_button(_lan, "JOIN WITH CODE", func() -> void:
		if Net.join(_code_entry.text):
			_lan_note.text = "DIALLING..."
		_refresh_lan())
	_button(_lan, "BACK", func() -> void:
		Net.close()
		_show_lan(false))
	Net.state_changed.connect(_refresh_lan)
	Net.failed.connect(func(why: String) -> void:
		_lan_note.text = why.to_upper()
		_refresh_lan())


func _refresh_lan() -> void:
	if _code_label == null:
		return
	match Net.role:
		Net.Role.HOSTING:
			_code_label.text = Net.code
			if Net.players.size() > 1:
				_lan_note.text = "%d WITH YOU. PRESS PLAY." % (Net.players.size() - 1)
		Net.Role.JOINING:
			_code_label.text = Net.code
		Net.Role.JOINED:
			_code_label.text = Net.code
			_lan_note.text = "IN. WAIT FOR THE HOST."
		_:
			_code_label.text = ""


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _button(parent: Control, caption: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(300, 52)
	b.add_theme_font_size_override(&"font_size", 24)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## PLAY says where it is going; NEW GAME only shows once there is something to lose.
func _refresh() -> void:
	if _play == null:
		return
	var has_progress: bool = Game.best_floor > 0
	_fresh.visible = has_progress
	_play.text = "PLAY" if not has_progress else "CONTINUE  %s" % \
		Game.floor_label(Game.FLOORS[clampi(Game.best_floor, 0, Game.FLOORS.size() - 1)])
	if not visible:
		_show_settings(false)
		_show_lan(false)
	if _stage != null and is_instance_valid(_stage):
		_stage.visible = visible
		if visible:
			_stage.show_again()
		else:
			_stage.release()
