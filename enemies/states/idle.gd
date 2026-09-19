class_name DudeIdle
extends DudeState


func enter() -> void:
	dude.desired_velocity = Vector3.ZERO


func update(_wd: float) -> StringName:
	if dude.alerted or dude.can_see_player:
		return &"alert"
	return &""
