class_name Director
extends PinkDude
## The boss. Bigger, two pistols, shrugs off blunt hits, takes three bullets.
## Every bullet that does not kill him makes him flinch and call a wave.

signal flinched(bullets_left: int)

var bullets_left: int = 3
var off_hand_weapon: Pistol = null

var _fire_left_next: bool = false


func _ready() -> void:
	body_scale = T.director_scale
	bullets_left = T.director_hp
	armed_at_spawn = true
	super()
	var off_hand := Node3D.new()
	off_hand.name = "OffHand"
	off_hand.position = Vector3(0, -0.66, 0)
	off_hand.rotation.x = -PI * 0.5
	parts[&"arm_l"].add_child(off_hand)
	off_hand_weapon = Pistol.create()
	off_hand_weapon.attach_to(off_hand)


func aim_time() -> float:
	return T.director_cadence * 0.65


func reposition_time() -> float:
	return T.director_cadence * 0.35


func muzzle() -> Vector3:
	var side: float = -0.3 if _fire_left_next else 0.3
	return super() + global_transform.basis.x.normalized() * side * body_scale


func shoot() -> void:
	super()
	_fire_left_next = not _fire_left_next


## Nobody takes the Director's guns.
func disarm() -> void:
	pass


func on_bullet_hit(bullet: Node, point: Vector3, _normal: Vector3) -> void:
	if not alive:
		return
	bullets_left -= 1
	if bullets_left <= 0:
		die(point, (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO)
		return
	Shatter.burst(Game.entities_root(self), point, 6, Mats.pink(), Vector3.ONE * 0.1, Vector3.UP, 0.12)
	Sfx.play(&"shatter", global_position)
	stun(T.director_flinch)
	flinched.emit(bullets_left)
	Game.spawn_wave(T.director_wave_size, T.director_wave_size - 1)


func _take_blunt(_damage: int, stun_time: float, _push: Vector3) -> void:
	if alive:
		Sfx.play(&"punch", global_position)
		stun(stun_time * 0.4)


func die(at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO) -> void:
	if alive and off_hand_weapon != null and is_instance_valid(off_hand_weapon):
		off_hand_weapon.ammo = T.pistol_ammo
		off_hand_weapon.drop(global_position + Vector3(-0.4, 1.4, 0))
		off_hand_weapon = null
	super(at, push)


func _animate(wd: float) -> void:
	super(wd)
	# Both arms come up when he aims.
	parts[&"arm_l"].rotation.x = parts[&"arm_r"].rotation.x if (aiming or winding_up) else parts[&"arm_l"].rotation.x
