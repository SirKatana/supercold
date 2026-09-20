class_name Warden
extends ShieldDude
## The second boss: a giant behind a tower shield. The glass in it is thick. It takes three
## rounds through the slit, and each one that lands makes him reel and call in troopers.
## A blast or the laser counts as one. Nothing else touches him.

signal health_changed(left: int, total: int)

var glass_left: int = 3


func _ready() -> void:
	body_scale = T.warden_scale
	super()
	add_to_group(&"bosses")
	glass_left = T.warden_glass_hits


func body_bulk() -> float:
	return 1.25


func voice_name_id() -> StringName:
	return &"name_warden"


func boss_name() -> String:
	return "THE WARDEN"


func boss_health() -> Vector2i:
	return Vector2i(glass_left, T.warden_glass_hits)


func can_freeze() -> bool:
	return false


func can_slip() -> bool:
	return false


func freeze(_seconds: float) -> void:
	stun(1.0)


func visor_shot(direction: Vector3) -> void:
	if not alive:
		return
	glass_left -= 1
	health_changed.emit(maxi(glass_left, 0), T.warden_glass_hits)
	Sfx.play(&"shatter", eye_position())
	Shatter.burst(Game.entities_root(self), eye_position() - global_transform.basis.z * 0.5, 8, Mats.visor_glass(),
		Vector3(0.2, 0.08, 0.05), -direction * 1.5, 0.06)
	if glass_left <= 0:
		die(eye_position(), direction)
		return
	stun(1.3)
	Game.spawn_wave(3, 3, &"shield" if glass_left == 1 else &"pistol")


func on_laser(direction: Vector3) -> void:
	visor_shot(direction)


func on_explosion(centre: Vector3) -> void:
	visor_shot((global_position - centre).normalized())


func _animate(wd: float) -> void:
	super(wd)
	# The tower shield is as oversized as he is.
	if shield_anchor != null:
		shield_anchor.global_transform.basis = shield_anchor.global_transform.basis.orthonormalized().scaled(Vector3.ONE * body_scale)
