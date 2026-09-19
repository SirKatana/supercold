class_name DudeFire
extends DudeState
## One attack: a single shot for a pistol or shotgun, a short burst for a rifle.

var _shots_left: int = 0
var _gap: float = 0.0


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO
	dude.aiming = true
	_shots_left = dude.burst_size() - 1
	_gap = dude.burst_gap()
	dude.shoot()


func exit() -> void:
	dude.aiming = false


func update(wd: float) -> StringName:
	if _shots_left <= 0 or not dude.has_weapon():
		return &"reposition"
	dude.face_toward(dude.player_position(), wd)
	_gap -= wd
	if _gap <= 0.0:
		_gap = dude.burst_gap()
		_shots_left -= 1
		dude.shoot()
	return &""
