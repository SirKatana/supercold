class_name Knifeman
extends PinkDude
## Burnt orange, and he only wants to get close. He sprints, slashes from a little further than
## a fist reaches, and if you keep away from him too long he throws the knife at you instead
## and comes on bare-handed. Any bullet kills him like anyone else.

var has_knife: bool = true

var _blade: Pickup
var _out_of_reach: float = 0.0


func _ready() -> void:
	armed_at_spawn = false
	body_scale = 0.97
	body_material = Mats.knifeman()
	super()
	hp = 2
	seeks_weapons = false
	_blade = Knife.create()
	add_child(_blade)
	_blade.state = Pickup.State.HELD
	_blade.collision_layer = 0
	_blade.collision_mask = 0
	_blade.set_physics_process(false)


func voice_name_id() -> StringName:
	return &"name_knifeman"


func seeks_cover() -> bool:
	return false


func move_speed() -> float:
	return T.knifeman_speed


func punch_windup() -> float:
	return T.knifeman_windup


## A blade reaches further than a fist, and that is the whole of him.
func punch_range() -> float:
	return T.knifeman_reach if has_knife else T.dude_punch_range


func punch_sound() -> StringName:
	return &"stab"


## The blade rides in the hand, and it is placed wherever the body is posed.
func _animate(wd: float) -> void:
	super(wd)
	if is_instance_valid(_blade):
		_blade.visible = has_knife and alive
		if _blade.visible:
			_blade.global_transform = hand_anchor.global_transform


func _physics_process(delta: float) -> void:
	super(delta)
	if not alive:
		return
	if not has_knife or not can_see_player or state_name == &"dead":
		_out_of_reach = 0.0
		return
	# Out of reach for long enough, and with a clear line: the knife goes to you instead.
	var wd: float = TimeManager.world_delta(delta)
	if dist_to_player > punch_range() + 1.2 and dist_to_player <= T.knifeman_throw_range:
		_out_of_reach += wd
		if _out_of_reach >= T.knifeman_throw_wait:
			_throw_the_knife()
	else:
		_out_of_reach = 0.0


func _throw_the_knife() -> void:
	has_knife = false
	_out_of_reach = 0.0
	var p: Player = get_player()
	if p == null:
		return
	var from: Vector3 = eye_position() - global_transform.basis.z * 0.3
	var flying: Knife = Knife.create()
	Game.entities_root(self).add_child(flying)
	var flight: float = from.distance_to(p.chest_position()) / (T.throw_speed * T.spear_throw_speed)
	var lead: Vector3 = p.chest_position() + Vector3(p.get_real_velocity().x, 0, p.get_real_velocity().z) * flight * 0.8
	flying.throw_from(from, (lead - from).normalized() * T.throw_speed * 1.25 + Vector3.UP * 0.5, self)
	Sfx.play(&"throw", from)


## Killed, he drops whatever is left: a knife for the player, if he still had it.
func die(at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO, style: StringName = &"ragdoll") -> void:
	if alive and has_knife:
		has_knife = false
		var dropped: Knife = Knife.create()
		Game.entities_root(self).add_child(dropped)
		dropped.drop(global_position + Vector3(0, 1.1, 0) - global_transform.basis.z * 0.3)
	if is_instance_valid(_blade):
		_blade.queue_free()
	super(at, push, style)


func display_name() -> String:
	return "A KNIFEMAN"
