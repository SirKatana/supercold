class_name SettingsPanel
extends VBoxContainer
## The settings controls, in one place: the pause menu and the main menu both put this in a box
## of their own. Every control writes straight into Settings and applies it, so there is no OK
## button and nothing to save.


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	_slider("MOUSE SENSITIVITY", 0.02, 0.4, 0.01, Settings.mouse_sensitivity,
		func(v: float) -> void: Settings.mouse_sensitivity = v)
	_slider("FIELD OF VIEW", 60.0, 110.0, 1.0, Settings.fov,
		func(v: float) -> void: Settings.fov = v)
	_slider("VOLUME", 0.0, 1.0, 0.05, Settings.volume,
		func(v: float) -> void: Settings.volume = v)

	var shades := CheckButton.new()
	shades.text = "SUNGLASSES ON ENEMIES"
	shades.button_pressed = Settings.sunglasses
	for state: StringName in [&"font_color", &"font_pressed_color", &"font_hover_color", &"font_hover_pressed_color"]:
		shades.add_theme_color_override(state, Color(0.04, 0.04, 0.05))
	shades.toggled.connect(func(on: bool) -> void:
		Settings.sunglasses = on
		Settings.apply())
	add_child(shades)


func _slider(caption: String, low: float, high: float, step: float, value: float, on_change: Callable) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override(&"font_color", Color(0.04, 0.04, 0.05))
	add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		Settings.apply())
	add_child(slider)
