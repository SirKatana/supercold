class_name WordFlash
extends Label
## Huge centred words, one at a time. SUPER. COLD.

var _serial: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override(&"font_size", 150)
	add_theme_color_override(&"font_color", Color(0.04, 0.04, 0.05))
	add_theme_color_override(&"font_outline_color", Color(1, 1, 1, 0.9))
	add_theme_constant_override(&"outline_size", 14)
	text = ""


func flash(words: PackedStringArray, interval: float = 0.42, loops: int = 1) -> void:
	_serial += 1
	var serial: int = _serial
	for i: int in loops:
		for word: String in words:
			text = word
			await get_tree().create_timer(interval, true, false, true).timeout
			if serial != _serial:
				return
	text = ""


func clear() -> void:
	_serial += 1
	text = ""
