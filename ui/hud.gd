class_name Hud
extends CanvasLayer
## Crosshair, ammo pips, slow-mo overlay, debug readout. Children are built in code.

var _slowmo: ColorRect
var _slowmo_material: ShaderMaterial
var _crosshair: ColorRect
var _debug: Label
var _amount: float = 0.0


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
