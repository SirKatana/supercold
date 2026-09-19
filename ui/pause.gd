class_name PauseMenu
extends CanvasLayer
## Esc toggles. Sliders write straight into Settings.

var _panel: PanelContainer


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.95, 0.96, 0.98, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override(&"separation", 14)
	centre.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 56)
	title.add_theme_color_override(&"font_color", Color(0.04, 0.04, 0.05))
	box.add_child(title)

	_slider(box, "MOUSE SENSITIVITY", 0.02, 0.4, 0.01, Settings.mouse_sensitivity,
		func(v: float) -> void: Settings.mouse_sensitivity = v)
	_slider(box, "FIELD OF VIEW", 60.0, 110.0, 1.0, Settings.fov, func(v: float) -> void: Settings.fov = v)
	_slider(box, "VOLUME", 0.0, 1.0, 0.05, Settings.volume, func(v: float) -> void: Settings.volume = v)

	_button(box, "RESUME", close)
	_button(box, "RESTART FLOOR", func() -> void:
		close()
		Game.restart_floor.call_deferred())
	_button(box, "QUIT", func() -> void: get_tree().quit())


func _slider(parent: Control, caption: String, low: float, high: float, step: float, value: float, on_change: Callable) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override(&"font_color", Color(0.04, 0.04, 0.05))
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		Settings.apply())
	parent.add_child(slider)


func _button(parent: Control, caption: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(on_press)
	parent.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if visible:
		close()
	elif Game.state == Game.State.PLAYING or Game.state == Game.State.CLEARED:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
