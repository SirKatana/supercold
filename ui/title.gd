class_name TitleScreen
extends CanvasLayer
## White screen, black words. Click to start.

signal start_requested(from_floor: int)

var _continue: Button


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.95, 0.96, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 18)
	add_child(box)

	box.add_child(_label("SUPER", 130, Color(0.04, 0.04, 0.05)))
	box.add_child(_label("COLD", 130, Mats.PINK))
	box.add_child(_label("TIME CRAWLS WHEN YOU STAND STILL", 24, Color(0.04, 0.04, 0.05)))
	box.add_child(_label("", 10, Color.BLACK))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 24)
	box.add_child(buttons)
	_continue = _button(buttons, "CONTINUE", func() -> void: start_requested.emit(Game.best_floor))
	_button(buttons, "NEW GAME", func() -> void:
		Game.erase_progress()
		start_requested.emit(0))
	visibility_changed.connect(_refresh)
	_refresh()
	box.add_child(_label("WASD move   MOUSE look   LMB punch / shoot   RMB grab / throw   E swap   Q throw   F shield   RMB scope (sniper)   R restart   ESC pause",
		16, Color(0.3, 0.32, 0.36)))


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
	b.custom_minimum_size = Vector2(240, 56)
	b.add_theme_font_size_override(&"font_size", 24)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## Continue only shows once there is somewhere to continue from.
func _refresh() -> void:
	if _continue == null:
		return
	_continue.visible = Game.best_floor > 0
	_continue.text = "CONTINUE  %s" % Game.floor_label(Game.FLOORS[clampi(Game.best_floor, 0, Game.FLOORS.size() - 1)])
