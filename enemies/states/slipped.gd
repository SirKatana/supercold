class_name DudeSlipped
extends DudeState
## Feet out from under him on something wet. He slides, lies there, then gets up without his gun.

var slide: Vector3 = Vector3.ZERO


func enter() -> void:
	dude.aiming = false
	dude.alerted = true
	dude.slipped = true
	dude.disarm()
	dude.desired_velocity = slide


func exit() -> void:
	dude.slipped = false
	dude.desired_velocity = Vector3.ZERO
	dude.last_slip = 0.0


func update(wd: float) -> StringName:
	slide = slide.lerp(Vector3.ZERO, minf(1.0, wd * 1.6))
	dude.desired_velocity = slide
	if time >= T.slip_seconds:
		return &"approach" if dude.has_weapon() else &"disarmed"
	return &""
