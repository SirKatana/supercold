class_name DuctLamp
extends Node3D
## A little lamp in the roof of a duct, of the sort nobody has changed in years. It is mostly
## on, with the odd blink: flickering it every few frames made the whole tunnel strobe, and the
## light only updates when it actually changes.

var _phase: float = 0.0
var _rate: float = 1.0
var _on: bool = true
var _lamp: OmniLight3D
var _glass: MeshInstance3D
var _bright: StandardMaterial3D
var _dim: StandardMaterial3D


func _ready() -> void:
	_phase = randf() * 10.0
	_rate = randf_range(0.5, 1.1)
	_bright = Mats.lift_light()
	_dim = Mats.gunmetal()
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshKit.cached(&"duct_lamp", _model)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	_glass = MeshInstance3D.new()
	var pane := BoxMesh.new()
	pane.size = Vector3(0.26, 0.012, 0.12)
	_glass.mesh = pane
	_glass.material_override = _bright
	_glass.position.y = -0.045
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)
	_lamp = OmniLight3D.new()
	_lamp.position.y = -0.14
	_lamp.omni_range = 3.4
	_lamp.light_energy = 0.5
	_lamp.light_color = Color(0.85, 0.93, 1.0)
	_lamp.shadow_enabled = false
	add_child(_lamp)


static func _model(kit: MeshKit) -> void:
	kit.box(Vector3(0.32, 0.05, 0.18), Vector3(0, -0.02, 0), Mats.gunmetal())
	kit.box(Vector3(0.05, 0.03, 0.20), Vector3(-0.14, -0.05, 0), Mats.steel())
	kit.box(Vector3(0.05, 0.03, 0.20), Vector3(0.14, -0.05, 0), Mats.steel())


func _process(delta: float) -> void:
	_phase += delta * _rate
	# One short blink every several seconds, and nothing in between.
	var blink: float = fmod(_phase, 7.4)
	var on: bool = blink > 0.22
	if on == _on:
		return      # nothing to write: a light that is set every frame costs every frame
	_on = on
	_lamp.light_energy = 0.55 if on else 0.05
	_glass.material_override = _bright if on else _dim
