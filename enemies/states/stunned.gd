class_name DudeStunned
extends DudeState

var duration: float = 1.2


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO
	dude.stunned = true
	dude.alerted = true


func exit() -> void:
	dude.stunned = false


func update(_wd: float) -> StringName:
	if time >= duration:
		return &"approach" if dude.has_weapon() else &"disarmed"
	return &""
