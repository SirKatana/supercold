class_name DudeReposition
extends DudeState
## Sidestep between shots so the dudes are not turrets. Lasts the rest of the fire cadence.


func enter() -> void:
	dude.pick_reposition_target()


func update(wd: float) -> StringName:
	if not dude.has_weapon():
		return &"disarmed"
	dude.move_along_path(wd)
	if time >= dude.reposition_time():
		return &"aim" if dude.can_see_player else &"approach"
	return &""
