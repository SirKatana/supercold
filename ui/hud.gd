class_name Hud
extends CanvasLayer
## Crosshair, ammo pips, slow-mo overlay, debug readout. Children are built in code.

var _slowmo: ColorRect
var _slowmo_material: ShaderMaterial
var _crosshair: ColorRect
var _debug: Label
var _amount: float = 0.0
var _pips: HBoxContainer


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS

	_slowmo = ColorRect.new()
	_slowmo.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	Game.floor_loaded.connect(_on_floor_loaded)
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
	if _debug.visible:
		_debug.text = "world_scale %.2f   fps %d" % [TimeManager.world_scale, Engine.get_frames_per_second()]


func _on_floor_loaded(_data: LevelData) -> void:
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
