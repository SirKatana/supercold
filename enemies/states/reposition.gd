class_name DudeReposition
extends DudeState
## Between shots a dude runs for cover and waits there a moment, so it is a target only
## while it aims. With no cover in reach it sidesteps for the rest of the fire cadence.

var _stay: float = 0.0
var _arrived_at: float = -1.0


func enter() -> void:
	_arrived_at = -1.0
	dude.pick_reposition_target()
	_stay = randf_range(T.dude_hide_min, T.dude_hide_max) if dude.hiding else 0.0


func exit() -> void:
	dude.hiding = false


func update(wd: float) -> StringName:
	if not dude.has_weapon():
		return &"disarmed"
	dude.move_along_path(wd)
	if _arrived_at < 0.0 and (dude.agent.is_navigation_finished() or dude.desired_velocity == Vector3.ZERO):
		_arrived_at = time
	var done: bool = time >= dude.reposition_time() and _arrived_at >= 0.0 and time - _arrived_at >= _stay
	if done or time >= T.dude_reposition_max:
		return &"aim" if dude.can_see_player else &"approach"
	return &""
