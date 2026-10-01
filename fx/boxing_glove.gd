class_name BoxingGlove
extends Node3D
## The thing that stops you leaving the building. Step off the edge or out of a broken window
## and a enormous red boxing glove swings out on a telescopic arm, puts you back inside, and
## retracts as if nothing happened.
##
## It runs on real time: it is a punchline, not part of the fight.

signal connected

const T: Tuning = preload("res://data/tuning.tres")
const REACH: float = 3.4
const PUNCH_SECONDS: float = 0.16
const HOLD_SECONDS: float = 0.12
const BACK_SECONDS: float = 0.35

var _arm: Node3D
var _glove: MeshInstance3D
var _clock: float = 0.0
var _hit: bool = false
var _target: Node3D = null
var _shove: Vector3 = Vector3.ZERO


## Swings out of `from`, pointing at `at`, and knocks `who` back that way.
static func swing(parent: Node, from: Vector3, toward: Vector3, who: Node3D) -> BoxingGlove:
	var fist := BoxingGlove.new()
	fist.name = "BoxingGlove"
	parent.add_child(fist)
	fist.global_position = from
	fist.look_at_from_position(from, from + toward, Vector3.UP)
	fist._target = who
	fist._shove = toward.normalized()
	return fist


func _ready() -> void:
	add_to_group(&"boxing_gloves")
	_arm = Node3D.new()
	add_child(_arm)
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshKit.cached(&"boxing_glove", _model)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm.add_child(mesh)
	_glove = mesh
	_arm.position.z = 0.1


func _process(delta: float) -> void:
	_clock += delta
	if _clock < PUNCH_SECONDS:
		var out: float = _clock / PUNCH_SECONDS
		_arm.position.z = -REACH * (out * out)
		return
	if not _hit:
		_hit = true
		Sfx.play(&"punch", global_position)
		if _target != null and is_instance_valid(_target) and _target.has_method(&"punched_back"):
			_target.call(&"punched_back", _shove)
		connected.emit()
		return
	if _clock < PUNCH_SECONDS + HOLD_SECONDS:
		return
	var back: float = (_clock - PUNCH_SECONDS - HOLD_SECONDS) / BACK_SECONDS
	_arm.position.z = lerpf(-REACH, 0.6, clampf(back, 0.0, 1.0))
	if back >= 1.0:
		queue_free()


## A fat red glove on a chrome telescope. -Z is the way it throws the punch.
static func _model(kit: MeshKit) -> void:
	var red: Material = Mats.glove_red()
	var lace: Material = Mats.white_paint()
	var chrome: Material = Mats.steel()
	# The telescope, in three stages, so it reads as a joke machine and not a pole.
	kit.tube(0.13, 0.15, 1.5, Vector3(0, 0, 0.95), chrome, true, 10)
	kit.tube(0.10, 0.12, 1.1, Vector3(0, 0, 0.10), chrome, true, 10)
	kit.tube(0.085, 0.095, 0.7, Vector3(0, 0, -0.42), chrome, true, 10)
	# The glove: a big ball with a thumb and a cuff.
	kit.ball(0.42, Vector3(0, 0, -0.92), red, Vector3(1.0, 0.92, 1.12))
	kit.ball(0.19, Vector3(0.26, -0.10, -0.80), red, Vector3(1.0, 0.9, 1.25))        # thumb
	kit.tube(0.30, 0.33, 0.26, Vector3(0, 0, -0.60), red, true, 12)                  # cuff
	kit.tube(0.315, 0.315, 0.05, Vector3(0, 0, -0.60), lace, true, 12)               # trim
	for i: int in 3:
		kit.box(Vector3(0.012, 0.10, 0.012), Vector3(0, 0.30, -0.80 + i * 0.07), lace)
