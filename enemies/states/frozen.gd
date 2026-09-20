class_name DudeFrozen
extends DudeState
## Solid ice. He does nothing until it wears off, and anything that hits him shatters him.

var duration: float = 7.0


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO
	dude.aiming = false
	dude.set_frozen(true)


func exit() -> void:
	dude.set_frozen(false)


func update(_wd: float) -> StringName:
	if time >= duration:
		return &"approach" if dude.has_weapon() else &"disarmed"
	return &""
