class_name Beast
extends PinkDude
## What they were growing in the basement. Twice your size, red over green, and no weapon: he
## does not need one. He walks you down, and every few seconds he drops his head and charges
## flat out, which is the only time he is faster than you. Get out of the lane and he goes past.
##
## Fourteen rounds. The guards with the carrot guns are his, and they keep firing while he works.

signal health_changed(left: int, total: int)

var hp_left: int = 14

var _charge_clock: float = 0.0
var _charging: float = -1.0
var _charge_dir: Vector3 = Vector3.ZERO
var _swipe: float = -1.0
var _gradient: ShaderMaterial


func _ready() -> void:
	body_scale = T.beast_scale
	armed_at_spawn = false
	_gradient = ShaderMaterial.new()
	_gradient.shader = preload("res://fx/gradient.gdshader")
	_gradient.set_shader_parameter(&"low_colour", Color(0.10, 0.90, 0.22))
	_gradient.set_shader_parameter(&"high_colour", Color(0.95, 0.08, 0.10))
	_gradient.set_shader_parameter(&"span", 1.85 * T.beast_scale)
	body_material = _gradient
	super()
	add_to_group(&"bosses")
	hp_left = T.beast_hp
	seeks_weapons = false
	skin.set_sunglasses(false)
	_charge_clock = T.beast_charge_every * 0.6


func body_bulk() -> float:
	return 1.45


func voice_name_id() -> StringName:
	return &"name_beast"


func boss_name() -> String:
	return "THE THING IN THE TANK"


func boss_health() -> Vector2i:
	return Vector2i(hp_left, T.beast_hp)


func wears_shades() -> bool:
	return false


func seeks_cover() -> bool:
	return false


func can_freeze() -> bool:
	return false


func can_choke() -> bool:
	return false


func can_slip() -> bool:
	return false


func move_speed() -> float:
	return T.beast_charge_speed if _charging >= 0.0 else T.beast_speed


func punch_range() -> float:
	return T.beast_swipe_range


func punch_windup() -> float:
	return T.beast_swipe_windup


func punch_sound() -> StringName:
	return &"slam"


func freeze(_seconds: float) -> void:
	stun(1.2)


func disarm() -> void:
	pass


func _physics_process(delta: float) -> void:
	super(delta)
	# The gradient is taken from world height, so it has to follow him up and down.
	_gradient.set_shader_parameter(&"base_y", global_position.y)
	if not alive or stunned:
		_charging = -1.0
		return
	var wd: float = TimeManager.world_delta(delta)
	if _charging >= 0.0:
		_charging += wd
		desired_velocity = _charge_dir * T.beast_charge_speed
		face_toward(global_position + _charge_dir, wd)
		var p: Player = get_player()
		if p != null and p.alive and flat_distance_to(p.global_position) <= T.beast_swipe_range * 0.8:
			p.hit_from(p.global_position - global_position)
		if _charging >= 1.2 or is_on_wall():
			_charging = -1.0
			_charge_clock = T.beast_charge_every
			stun(0.7)      # he goes into the wall and it takes him a moment
			Sfx.play(&"slam", global_position)
			Shatter.burst(Game.entities_root(self), global_position + Vector3(0, 1.4, 0), 10, Mats.floor_mat(),
				Vector3(0.6, 0.4, 0.6), Vector3.UP * 2.0, 0.14)
			var watcher: Player = get_player()
			if watcher != null:
				watcher.fx.shake(0.08)
		return
	_charge_clock -= wd
	if _charge_clock <= 0.0 and can_see_player and dist_to_player <= T.beast_charge_range and dist_to_player > T.beast_swipe_range:
		_charging = 0.0
		_charge_dir = (player_position() - global_position) * Vector3(1, 0, 1)
		_charge_dir = _charge_dir.normalized() if _charge_dir.length() > 0.1 else -global_transform.basis.z
		Sfx.play(&"choke", global_position)


func hurt(amount: int, at: Vector3, push: Vector3) -> void:
	if not alive:
		return
	hp_left -= amount
	health_changed.emit(maxi(hp_left, 0), T.beast_hp)
	Shatter.burst(Game.entities_root(self), at, 5, Mats.specimen(), Vector3.ONE * 0.12, Vector3.UP, 0.13)
	Sfx.play(&"punch", global_position)
	alerted = true
	if hp_left <= 0:
		die(at, push)


func on_bullet_hit(bullet: Node, point: Vector3, _normal: Vector3) -> bool:
	hurt(1, point, (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO)
	return false


func on_laser(direction: Vector3) -> void:
	hurt(4, global_position + Vector3.UP * 1.8, direction)


func on_explosion(centre: Vector3) -> void:
	hurt(5, global_position + Vector3.UP * 1.8, global_position - centre)


func on_stabbed(direction: Vector3) -> void:
	hurt(2, global_position + Vector3.UP * 1.6, direction)


func on_rammed(direction: Vector3) -> void:
	hurt(3, global_position + Vector3.UP * 1.6, direction)


func _take_blunt(_damage: int, _stun_time: float, _push: Vector3) -> void:
	Sfx.play(&"punch", global_position)
