class_name Hud
extends CanvasLayer
## Crosshair, ammo pips, slow-mo overlay, debug readout. Children are built in code.

var _slowmo: ColorRect
var _slowmo_material: ShaderMaterial
var _crosshair: ColorRect
var _debug: Label
var _amount: float = 0.0
var _pips: HBoxContainer
var _words: WordFlash
var _intro: Label
var _hint: Label


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS

	_slowmo = ColorRect.new()
	_slowmo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slowmo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slowmo_material = ShaderMaterial.new()
	_slowmo_material.shader = preload("res://fx/slowmo.gdshader")
	_slowmo.material = _slowmo_material
	add_child(_slowmo)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(0.05, 0.05, 0.06, 0.9)
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-2, -2)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	_pips = HBoxContainer.new()
	_pips.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pips.position = Vector2(-60, -48)
	_pips.add_theme_constant_override(&"separation", 6)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pips)
	_intro = Label.new()
	_intro.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_intro.position = Vector2(-400, 90)
	_intro.size = Vector2(800, 120)
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_theme_font_size_override(&"font_size", 30)
	_intro.add_theme_color_override(&"font_color", Color(0.04, 0.04, 0.05))
	add_child(_intro)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-400, -110)
	_hint.size = Vector2(800, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override(&"font_size", 22)
	_hint.add_theme_color_override(&"font_color", Color(0.04, 0.04, 0.05))
	add_child(_hint)

	_words = WordFlash.new()
	add_child(_words)

	Game.floor_loaded.connect(_on_floor_loaded)
	Game.state_changed.connect(_on_state_changed)
	Game.floor_announced.connect(_on_floor_announced)
	if Game.player != null:
		_on_floor_loaded(Game.data)

	_debug = Label.new()
	_debug.position = Vector2(12, 8)
	_debug.add_theme_color_override(&"font_color", Color(0.1, 0.1, 0.12))
	_debug.visible = OS.is_debug_build()
	add_child(_debug)


func _process(delta: float) -> void:
	_amount = lerpf(_amount, 1.0 - TimeManager.world_scale, minf(1.0, delta * 10.0))
	_slowmo_material.set_shader_parameter(&"amount", _amount)
	if Input.is_action_just_pressed(&"debug_overlay"):
		_debug.visible = not _debug.visible
	if Game.player != null and is_instance_valid(Game.player) and Game.player.alive:
		_prompt_shield()
	if _debug.visible:
		_debug.text = "world_scale %.2f   fps %d" % [TimeManager.world_scale, Engine.get_frames_per_second()]


func _on_state_changed(state: Game.State) -> void:
	match state:
		Game.State.CLEARED:
			_hint.text = "FLOOR CLEAR. GET TO THE HELIPAD." if Game.data != null and Game.data.exit_kind == &"helipad" \
				else "FLOOR CLEAR. HIT THE ELEVATOR BUTTON."
			_words.flash(["SUPER", "COLD"], 0.42, 2)
		Game.State.DEAD:
			_hint.text = "R TO RESTART"
			_words.flash(["DEAD"], 0.5)
		Game.State.PLAYING:
			_hint.text = ""
		_:
			_hint.text = ""
			_words.clear()
	visible = state != Game.State.TITLE and state != Game.State.ENDING


func _on_floor_loaded(_data: LevelData) -> void:
	_words.clear()
	_show_intro("")
	set_ammo(-1, 0)
	if Game.player != null and Game.player.hands != null:
		Game.player.hands.ammo_changed.connect(set_ammo)


## `ammo` below zero hides the pips (no pistol in hand).
func set_ammo(ammo: int, capacity: int) -> void:
	for child: Node in _pips.get_children():
		child.queue_free()
	if ammo < 0:
		return
	for i: int in capacity:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(8, 18)
		pip.color = Color(0.05, 0.05, 0.06, 0.9) if i < ammo else Color(0.05, 0.05, 0.06, 0.18)
		_pips.add_child(pip)


## Fired when the player walks out of the arrival lift.
func _on_floor_announced(label: String, intro: String) -> void:
	_words.flash([label], 1.1)
	_show_intro(intro)


func _show_intro(text: String) -> void:
	_intro.text = text
	_intro.modulate.a = 1.0
	if text == "":
		return
	var tween: Tween = create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(_intro, ^"modulate:a", 0.0, 0.8)


## "F  TAKE SHIELD" while one lies in reach, "F  DROP SHIELD" is never nagged.
func _prompt_shield() -> void:
	var wants: bool = Game.state == Game.State.PLAYING and Game.player.shield == null \
		and Game.player.hands.nearest_shield() != null
	if wants and _hint.text == "":
		_hint.text = "F  TAKE SHIELD"
	elif not wants and _hint.text == "F  TAKE SHIELD":
		_hint.text = ""
