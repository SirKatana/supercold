class_name DudeApproach
extends DudeState

var _repath: float = 0.0


func enter() -> void:
	_repath = 0.0


func update(wd: float) -> StringName:
	if not dude.has_weapon():
		return &"disarmed"
	if dude.can_see_player and dude.dist_to_player <= dude.engage_distance():
		return &"aim"
	_repath -= wd
	if _repath <= 0.0:
		_repath = 0.3
		dude.set_nav_target(dude.approach_point())
	dude.move_along_path(wd)
	return &""
