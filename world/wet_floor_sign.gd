class_name WetFloorSign
extends Node3D
## The yellow A-frame the cleaner leaves where he has mopped. It is only a picture: nothing
## collides with it, and it folds itself away after a while.

const STAYS: float = 25.0
var _age: float = 0.0


static func stand(parent: Node, at: Vector3) -> WetFloorSign:
	var sign := WetFloorSign.new()
	parent.add_child(sign)
	sign.global_position = Vector3(at.x, 0.0, at.z)
	sign.rotation.y = randf() * TAU
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"wet_floor_sign", _model)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sign.add_child(mi)
	sign.add_to_group(&"wet_floor_signs")
	return sign


## An A-frame: the two panels meet at the hinge on top and stand apart at the floor.
static func _model(kit: MeshKit) -> void:
	for face: float in [-1.0, 1.0]:
		kit.box(Vector3(0.30, 0.64, 0.012), Vector3(0, 0.31, 0.090 * face), Mats.rubber_yellow(), Vector3(-0.27 * face, 0, 0))
		kit.box(Vector3(0.20, 0.05, 0.004), Vector3(0, 0.45, 0.058 * face), Mats.polymer(), Vector3(-0.27 * face, 0, 0))     # CAUTION
		kit.box(Vector3(0.16, 0.16, 0.004), Vector3(0, 0.30, 0.100 * face), Mats.polymer(), Vector3(-0.27 * face, 0, PI * 0.25))   # the slipping man, more or less
	kit.box(Vector3(0.10, 0.03, 0.04), Vector3(0, 0.625, 0), Mats.polymer())      # hinge and handle


func _process(delta: float) -> void:
	_age += delta
	if _age > STAYS:
		queue_free()
	elif _age > STAYS - 0.5:
		scale = Vector3.ONE * maxf(0.01, (STAYS - _age) / 0.5)
