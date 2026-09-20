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
	add_to_group(&"bosses")
	off_hand_weapon = Pistol.create()
	off_hand_weapon.attach_to(off_hand_anchor)


func boss_name() -> String:
	return "THE DIRECTOR"


func boss_health() -> Vector2i:
	return Vector2i(bullets_left, T.director_hp)


## The boss does not hide. He keeps coming.
func seeks_cover() -> bool:
	return false


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


func on_bullet_hit(bullet: Node, point: Vector3, _normal: Vector3) -> bool:
	if not alive:
		return false
	bullets_left -= 1
	if bullets_left <= 0:
		die(point, (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO)
		return false
	Shatter.burst(Game.entities_root(self), point, 6, Mats.pink(), Vector3.ONE * 0.1, Vector3.UP, 0.12)
	Sfx.play(&"shatter", global_position)
	stun(T.director_flinch)
	flinched.emit(bullets_left)
	Game.spawn_wave(T.director_wave_size, T.director_wave_size - 1)
	return false


## A knife only annoys him.
func on_stabbed(_direction: Vector3) -> void:
	_take_blunt(0, T.throw_stun, Vector3.ZERO)


func can_freeze() -> bool:
	return false


func can_choke() -> bool:
	return false


func can_slip() -> bool:
	return false


## The laser costs him a hit like a bullet does. He is too big to melt in one go.
func on_laser(direction: Vector3) -> void:
	on_bullet_hit(null, global_position + Vector3.UP * 1.2, -direction)


## A blast hurts him as much as one bullet does.
func on_explosion(_centre: Vector3) -> void:
	on_bullet_hit(null, global_position + Vector3.UP, Vector3.UP)


func _take_blunt(_damage: int, stun_time: float, _push: Vector3) -> void:
	if alive:
		Sfx.play(&"punch", global_position)
		stun(stun_time * 0.4)


func die(at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO, style: StringName = &"ragdoll") -> void:
	if alive and off_hand_weapon != null and is_instance_valid(off_hand_weapon):
		off_hand_weapon.ammo = T.pistol_ammo
		off_hand_weapon.drop(global_position + Vector3(-0.4, 1.4, 0))
		off_hand_weapon = null
	super(at, push, style)


## Both arms come up when he aims: one pistol each.
func aim_left_amount() -> float:
	return _aim_raise
