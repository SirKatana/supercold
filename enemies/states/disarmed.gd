class_name DudeDisarmed
extends DudeState
## No gun. Go and get one if one is close, otherwise run at the player and punch.

var _repath: float = 0.0
var _windup: float = -1.0
var _target_weapon: Pistol = null


func enter() -> void:
	_repath = 0.0
	_windup = -1.0
	_target_weapon = null


func exit() -> void:
	dude.winding_up = false


func update(wd: float) -> StringName:
	if dude.has_weapon():
		return &"approach"

	if _windup >= 0.0:
		dude.desired_velocity = Vector3.ZERO
		dude.face_toward(dude.player_position(), wd)
		_windup += wd
		if _windup >= T.dude_punch_windup:
			_windup = -1.0
			dude.winding_up = false
			dude.land_punch()
		return &""

	_repath -= wd
	if _repath <= 0.0:
		_repath = 0.3
		_target_weapon = dude.find_free_pistol() if dude.seeks_weapons else null
		if _target_weapon != null:
			dude.set_nav_target(_target_weapon.global_position)
		else:
			dude.set_nav_target(dude.player_position())

	if _target_weapon != null and is_instance_valid(_target_weapon) and _target_weapon.is_available():
		if dude.flat_distance_to(_target_weapon.global_position) < 1.1:
			dude.take_weapon(_target_weapon)
			return &"approach"
	elif dude.dist_to_player <= T.dude_punch_range:
		_windup = 0.0
		dude.winding_up = true
		return &""

	dude.move_along_path(wd)
	return &""
