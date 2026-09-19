class_name DudeFire
extends DudeState


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO
	dude.shoot()


func update(_wd: float) -> StringName:
	return &"reposition"
