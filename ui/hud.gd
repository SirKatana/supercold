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
var _helper_clock: Label
var _glitch: ColorRect
var _glitch_material: ShaderMaterial
var _scope: ColorRect
var _boss_name: Label
var _underwater: float = 0.0
var _boss_back: ColorRect
var _boss_bar: ColorRect
var _scope_material: ShaderMaterial


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

	# The picture coming apart on the way down to the basement.
	_glitch = ColorRect.new()
	_glitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_material = ShaderMaterial.new()
	_glitch_material.shader = preload("res://fx/glitch.gdshader")
	_glitch.material = _glitch_material
	_glitch.visible = false
	add_child(_glitch)

	_scope = ColorRect.new()
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_material = ShaderMaterial.new()
	_scope_material.shader = preload("res://fx/scope.gdshader")
	_scope.material = _scope_material
	_scope.visible = false
	add_child(_scope)

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

	_helper_clock = Label.new()
	_helper_clock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_helper_clock.offset_left = -260
	_helper_clock.offset_right = -18
	_helper_clock.offset_top = 12
	_helper_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_helper_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_helper_clock.add_theme_font_size_override(&"font_size", 24)
	_helper_clock.add_theme_color_override(&"font_color", Color(0.85, 0.10, 0.08))
	add_child(_helper_clock)

	_boss_back = ColorRect.new()
	_boss_back.color = Color(0.05, 0.05, 0.06, 0.35)
	_boss_back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_back.offset_left = -260
	_boss_back.offset_right = 260
	_boss_back.offset_top = 56
	_boss_back.offset_bottom = 70
	_boss_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_back)
	_boss_bar = ColorRect.new()
	_boss_bar.color = Mats.PINK
	_boss_bar.position = Vector2(2, 2)
	_boss_bar.size = Vector2(516, 10)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_back.add_child(_boss_bar)
	_boss_name = Label.new()
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_name.offset_left = -260
	_boss_name.offset_right = 260
	_boss_name.offset_top = 26
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name.add_theme_font_size_override(&"font_size", 22)
	_boss_name.add_theme_color_override(&"font_color", Color(0.04, 0.04, 0.05))
	add_child(_boss_name)
	_words = WordFlash.new()
	add_child(_words)

	add_child(Minimap.new())      # hidden unless the player has switched it on

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
		_prompt_security()
	var boss: Node = get_tree().get_first_node_in_group(&"bosses")
	var show_boss: bool = boss != null and is_instance_valid(boss) and boss.get(&"alive") == true
	_boss_back.visible = show_boss
	_boss_name.visible = show_boss
	if show_boss:
		var health: Vector2i = boss.call(&"boss_health")
		_boss_name.text = boss.call(&"boss_name")
		_boss_bar.size.x = 516.0 * clampf(float(health.x) / maxf(health.y, 1), 0.0, 1.0)
	_glitch.visible = Game.glitch > 0.001
	if _glitch.visible:
		_hint.text = ""      # nothing on this screen is to be trusted on the way down
		_glitch_material.set_shader_parameter(&"amount", Game.glitch)
		_glitch_material.set_shader_parameter(&"time", Time.get_ticks_msec() / 1000.0)
	var stink: float = Game.player.in_stink if Game.player != null and is_instance_valid(Game.player) else 0.0
	_slowmo_material.set_shader_parameter(&"stink", clampf(stink / 0.3, 0.0, 1.0))
	var under: bool = Game.player != null and is_instance_valid(Game.player) and Game.player.head_under_water()
	_underwater = move_toward(_underwater, 1.0 if under else 0.0, delta * 6.0)
	_slowmo_material.set_shader_parameter(&"underwater", _underwater)
	_slowmo_material.set_shader_parameter(&"wobble_time", Time.get_ticks_msec() / 1000.0)
	var scoped: float = Game.player.fx.scope_amount if Game.player != null and is_instance_valid(Game.player) else 0.0
	_scope.visible = scoped > 0.02
	_crosshair.visible = scoped < 0.5
	if _scope.visible:
		var size: Vector2 = get_viewport().get_visible_rect().size
		_scope_material.set_shader_parameter(&"amount", scoped)
		_scope_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	var left: int = int(ceilf(Game.helper_time_left))
	_helper_clock.text = "HELPER %d:%02d" % [left / 60, left % 60] if left > 0 else ""
	if _debug.visible:
		_debug.text = "world_scale %.2f   fps %d" % [TimeManager.world_scale, Engine.get_frames_per_second()]


func _on_state_changed(state: Game.State) -> void:
	match state:
		Game.State.CLEARED:
			_hint.text = "FLOOR CLEAR. GET TO THE HELIPAD." if Game.data != null and Game.data.exit_kind == &"helipad" \
				else "FLOOR CLEAR. THE ELEVATOR HAS ARRIVED. HIT ITS BUTTON."
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


## While security is waiting for a weapon, say what he wants and how to give it to him.
func _prompt_security() -> void:
	var guard: SecurityGuard = Game.guard
	var waiting: bool = guard != null and is_instance_valid(guard) and guard.mode != SecurityGuard.Mode.LEAVING
	var line: String = "SECURITY: THROW HIM YOUR WEAPON (Q)"
	if waiting and guard.mode == SecurityGuard.Mode.FIRING:
		line = "THROW HIM THE WEAPON! PRESS Q"
	if waiting and (_hint.text == "" or _hint.text.begins_with("SECURITY") or _hint.text.begins_with("THROW HIM")):
		_hint.text = line
	elif not waiting and (_hint.text.begins_with("SECURITY") or _hint.text.begins_with("THROW HIM")):
		_hint.text = ""


## "F  TAKE SHIELD" while one lies in reach, "F  DROP SHIELD" is never nagged.
func _prompt_shield() -> void:
	var wants: bool = Game.state == Game.State.PLAYING and Game.player.shield == null \
		and Game.player.hands.nearest_shield() != null
	if wants and _hint.text == "":
		_hint.text = "F  TAKE SHIELD"
	elif not wants and _hint.text == "F  TAKE SHIELD":
		_hint.text = ""
