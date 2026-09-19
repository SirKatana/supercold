class_name DudeAlert
extends DudeState
## Short reaction delay so the player gets a beat after being spotted.


func enter() -> void:
	dude.alerted = true
	dude.desired_velocity = Vector3.ZERO


func update(wd: float) -> StringName:
	dude.face_toward(dude.player_position(), wd)
	if time >= T.dude_reaction:
		return &"approach" if dude.has_weapon() else &"disarmed"
	return &""
