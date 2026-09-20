class_name DudeChoking
extends DudeState
## Caught in the stink. Hands to his throat, doubled over, gagging. Too long in it and he
## drops where he stands.

var _gag: float = 0.0


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO
	dude.aiming = false
	dude.alerted = true
	dude.choking = true
	_gag = 0.0
	dude.disarm()      # both hands are going to his throat, so the gun goes


func exit() -> void:
	dude.choking = false


func update(wd: float) -> StringName:
	_gag -= wd
	if _gag <= 0.0:
		_gag = 0.95
		Sfx.play(&"choke", dude.global_position)
	if dude.choke_exposure >= T.fart_kill_time:
		# The smell finishes him. He folds forward out of the bend he was already in.
		Sfx.play(&"choke_die", dude.global_position)
		dude.die(dude.global_position + Vector3.UP, -dude.global_transform.basis.z * 0.35)
		return &""
	# Out of the gas for a moment: he recovers.
	if dude.gas_clock > 0.45:
		return &"approach" if dude.has_weapon() else &"disarmed"
	return &""
