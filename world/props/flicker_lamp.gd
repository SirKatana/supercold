class_name FlickerLamp
extends Node3D
## A strip light in the ceiling of a room that has not been maintained in years. It hums, it
## stutters, and every so often it goes out altogether for a second. Down in the basement they
## are most of the light there is.

const T: Tuning = preload("res://data/tuning.tres")

var _phase: float = 0.0
var _rate: float = 1.0
var _lamp: OmniLight3D
var _tube: MeshInstance3D
var _lit: StandardMaterial3D
var _dead: StandardMaterial3D


static func hang(parent: Node, at: Vector3) -> FlickerLamp:
	var lamp := FlickerLamp.new()
	parent.add_child(lamp)
	lamp.position = Vector3(at.x, T.wall_height - 0.08, at.z)
	lamp.rotation.y = 0.0 if int(at.x + at.z) % 2 == 0 else PI * 0.5
	return lamp


func _ready() -> void:
	add_to_group(&"flicker_lamps")
	_phase = randf() * 12.0
	_rate = randf_range(0.5, 1.9)
	_lit = Mats.lift_light()
	_dead = Mats.gunmetal()
	var frame := MeshInstance3D.new()
	frame.mesh = MeshKit.cached(&"flicker_lamp", _model)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frame)
	_tube = MeshInstance3D.new()
	var glass := BoxMesh.new()
	glass.size = Vector3(1.30, 0.05, 0.16)
	_tube.mesh = glass
	_tube.material_override = _lit
	_tube.position.y = -0.055
	_tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tube)
	_lamp = OmniLight3D.new()
	_lamp.position.y = -0.3
	_lamp.omni_range = 7.0
	_lamp.light_energy = 1.1
	_lamp.light_color = Color(0.86, 0.94, 1.0)
	_lamp.shadow_enabled = false
	add_child(_lamp)


static func _model(kit: MeshKit) -> void:
	var metal: Material = Mats.gunmetal()
	kit.box(Vector3(1.46, 0.07, 0.26), Vector3(0, 0, 0), metal)                    # housing
	kit.box(Vector3(0.06, 0.12, 0.22), Vector3(-0.70, -0.04, 0), metal)            # end caps
	kit.box(Vector3(0.06, 0.12, 0.22), Vector3(0.70, -0.04, 0), metal)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.03, 0.10, 0.03), Vector3(0.55 * side, 0.06, 0), Mats.steel())   # chains to the ceiling


func _process(delta: float) -> void:
	_phase += delta * _rate
	# Long spells on, a stutter, and now and then a second of nothing at all.
	var stutter: float = sin(_phase * 9.1) * sin(_phase * 2.3 + 0.7)
	var dead_spell: bool = fmod(_phase, 11.0) < 0.9
	var on: bool = stutter > -0.7 and not dead_spell
	_lamp.light_energy = 1.1 if on else 0.04
	_tube.material_override = _lit if on else _dead
