class_name EndingScreen
extends CanvasLayer
## Shown when the Director is dead and the player steps onto the helipad.

signal dismissed

var _stats: Label
var _shown_at: int = 0


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.95, 0.96, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 20)
	add_child(box)
	box.add_child(_label("THE HQ IS QUIET", 72, Color(0.04, 0.04, 0.05)))
	box.add_child(_label("SUPER COLD", 40, Mats.PINK))
	_stats = _label("", 26, Color(0.04, 0.04, 0.05))
	box.add_child(_stats)
	box.add_child(_label("CLICK TO RETURN", 22, Color(0.3, 0.32, 0.36)))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


func show_stats(seconds: float, deaths: int) -> void:
	var total: int = int(seconds)
	_stats.text = "TIME %d:%02d    DEATHS %d" % [total / 60, total % 60, deaths]
	_shown_at = Time.get_ticks_msec()
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Time.get_ticks_msec() - _shown_at < 800:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		visible = false
		dismissed.emit()
