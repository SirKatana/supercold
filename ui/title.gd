class_name TitleScreen
extends CanvasLayer
## White screen, black words. Click to start.

signal start_requested


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
	box.add_child(_label("CLICK TO START", 30, Color(0.04, 0.04, 0.05)))
	box.add_child(_label("WASD move   MOUSE look   LMB punch / shoot   RMB grab / throw   E swap   R restart   ESC pause",
		16, Color(0.3, 0.32, 0.36)))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		start_requested.emit()
