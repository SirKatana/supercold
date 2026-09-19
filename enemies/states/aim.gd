class_name DudeAim
extends DudeState
## The telegraph. Arm up, laser on, tracking the player's current position.


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO
	dude.aiming = true


func exit() -> void:
	dude.aiming = false


func update(wd: float) -> StringName:
	if not dude.has_weapon():
		return &"disarmed"
	if not dude.can_see_player:
		return &"approach"
	dude.face_toward(dude.player_position(), wd)
	if time >= dude.aim_time():
		return &"fire"
	return &""
