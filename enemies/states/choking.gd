class_name DudeChoking
extends DudeState
## Caught in the stink. Bent over, coughing, going nowhere. Too long in it and he drops.


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO
	dude.aiming = false
	dude.alerted = true
	dude.choking = true


func exit() -> void:
	dude.choking = false


func update(_wd: float) -> StringName:
	if dude.choke_exposure >= T.fart_kill_time:
		dude.die(dude.global_position + Vector3.UP, Vector3.ZERO)
		return &""
	# Out of the gas for a moment: he recovers.
	if dude.gas_clock > 0.45:
		return &"approach" if dude.has_weapon() else &"disarmed"
	return &""
