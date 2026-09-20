class_name ShieldDude
extends PinkDude
## SWAT trooper behind a ballistic shield. Bullets stop on the shield and on his armour.
## The only bullet that kills him is one through the glass viewport he looks out of.
## An explosion also does it. Blunt hits only stagger him. He never hides: he advances.

var shield: Shield
var shield_anchor: Node3D


func _ready() -> void:
	armed_at_spawn = true
	weapon_kind = &"pistol"
	super()
	seeks_weapons = false
	shield_anchor = _make_anchor("ShieldAnchor")
	shield = Shield.create()
	shield.give_to(self, shield_anchor)
	_animate(0.0)


func seeks_cover() -> bool:
	return false


## Gas mask.
func can_choke() -> bool:
	return false


## Frozen, he cannot hold the shield up: it stops protecting him.
func set_frozen(on: bool) -> void:
	super(on)
	if shield != null and is_instance_valid(shield):
		shield._set_solid(not on)


func move_speed() -> float:
	return T.shield_dude_speed


func reposition_time() -> float:
	return maxf(0.2, T.shield_dude_cadence - T.dude_aim_time)


## The shield arm stays up whatever he is doing.
func aim_left_amount() -> float:
	return 0.52


## He shoots around the right edge of the shield.
func muzzle() -> Vector3:
	return super() + global_transform.basis.x.normalized() * 0.40


func bullet_excludes() -> Array[RID]:
	return shield.collider_rids() if shield != null and is_instance_valid(shield) else []


func disarm() -> void:
	pass


## Body armour. It stops the round, and like the shield it sometimes turns it away.
func on_bullet_hit(_bullet: Node, point: Vector3, normal: Vector3) -> bool:
	if not alive:
		return false
	if frozen:
		die(point, Vector3.ZERO, &"ice")      # frozen armour is just brittle
		return false
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 4, Mats.steel(), Vector3.ONE * 0.02, normal * 2.0, 0.035)
	alerted = true
	if Shield.rolls_deflect():
		return true
	Sfx.play(&"door_hit", point)
	return false


## Armour turns a blade. It staggers him and that is all.
func on_stabbed(_direction: Vector3) -> void:
	_take_blunt(0, T.throw_stun, Vector3.ZERO)


## A bullet came through the glass.
func visor_shot(direction: Vector3) -> void:
	die(eye_position(), direction)


func _take_blunt(_damage: int, stun_time: float, push: Vector3) -> void:
	if alive and frozen:
		die(global_position + Vector3.UP, push, &"ice")
	elif alive:
		Sfx.play(&"punch", global_position)
		stun(stun_time * 0.5)


func die(at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO, style: StringName = &"ragdoll") -> void:
	if alive and shield != null and is_instance_valid(shield):
		var drop_at: Vector3 = global_position - global_transform.basis.z * 0.8
		shield.release_to_floor(drop_at)
		shield = null
	super(at, push, style)


func _animate(wd: float) -> void:
	super(wd)
	if shield_anchor != null:
		var forward: Vector3 = -global_transform.basis.z.normalized()
		var lean: float = 0.35 * _stagger      # a stagger tips the shield back with him
		shield_anchor.global_transform = Transform3D(
			global_transform.basis.orthonormalized() * Basis(Vector3.RIGHT, lean),
			global_position + forward * 0.58 - global_transform.basis.x.normalized() * 0.10)
