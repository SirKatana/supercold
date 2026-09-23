class_name Spearman
extends PinkDude
## Violet, unhurried, and he kills from further away than you can punch. He walks up to the
## end of his spear, holds there, and thrusts. Get inside the point and he is nothing.

var _spear: Pickup


func _ready() -> void:
	armed_at_spawn = false
	body_scale = 1.05
	body_material = Mats.spearman()
	super()
	hp = 3
	seeks_weapons = false
	_spear = Spear.create()
	add_child(_spear)
	_spear.state = Pickup.State.HELD
	_spear.collision_layer = 0
	_spear.collision_mask = 0
	_spear.set_physics_process(false)


func voice_name_id() -> StringName:
	return &"name_spearman"


func seeks_cover() -> bool:
	return false


func move_speed() -> float:
	return T.spearman_speed


func punch_windup() -> float:
	return T.spearman_windup


func punch_range() -> float:
	return T.spearman_reach


func punch_sound() -> StringName:
	return &"stab"


## Held two-handed, and levelled at the player while he winds up to thrust.
func _animate(wd: float) -> void:
	super(wd)
	if not is_instance_valid(_spear):
		return
	_spear.visible = alive
	var anchor: Transform3D = hand_anchor.global_transform
	if winding_up:
		var to_player: Vector3 = (player_position() + Vector3(0, 1.1, 0)) - anchor.origin
		if to_player.length() > 0.2:
			anchor = Transform3D(Basis.looking_at(to_player.normalized(), Vector3.UP), anchor.origin)
	_spear.global_transform = anchor


## He drops the spear when he goes down, and it is a fine weapon.
func die(at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO, style: StringName = &"ragdoll") -> void:
	if alive:
		var dropped: Spear = Spear.create()
		Game.entities_root(self).add_child(dropped)
		dropped.drop(global_position + Vector3(0, 1.0, 0) - global_transform.basis.z * 0.5)
	if is_instance_valid(_spear):
		_spear.queue_free()
	super(at, push, style)
