class_name Brute
extends PinkDude
## The first boss. Huge, wide, slow, and he does not care what you throw at him. He walks
## you down with a shotgun, and if you let him reach you he brings both fists down.
## Twelve hits. At two thirds and one third he roars and more dudes pour in.
## Kill him and the super gun is yours.

signal health_changed(left: int, total: int)

var hp_left: int = 12

var _waves_called: int = 0
var _slam_clock: float = -1.0


func _ready() -> void:
	body_scale = T.brute_scale
	armed_at_spawn = true
	weapon_kind = &"shotgun"
	super()
	add_to_group(&"bosses")
	hp_left = T.brute_hp
	seeks_weapons = false


func body_bulk() -> float:
	return 1.55


func voice_name_id() -> StringName:
	return &"name_brute"


func boss_name() -> String:
	return "THE BRUTE"


func boss_health() -> Vector2i:
	return Vector2i(hp_left, T.brute_hp)


func seeks_cover() -> bool:
	return false


func can_freeze() -> bool:
	return false


func can_choke() -> bool:
	return false


func can_slip() -> bool:
	return false


func move_speed() -> float:
	return T.brute_speed


func disarm() -> void:
	pass


## A freeze bomb only locks his joints for a moment.
func freeze(_seconds: float) -> void:
	stun(1.4)


func hurt(amount: int, at: Vector3, push: Vector3) -> void:
	if not alive:
		return
	hp_left -= amount
	health_changed.emit(maxi(hp_left, 0), T.brute_hp)
	Shatter.burst(Game.entities_root(self), at, 5, Mats.pink(), Vector3.ONE * 0.1, Vector3.UP, 0.12)
	Sfx.play(&"punch", global_position)
	alerted = true
	if hp_left <= 0:
		die(at, push)
		return
	var third: int = int(ceilf(T.brute_hp / 3.0))
	var due: int = (T.brute_hp - hp_left) / third
	if due > _waves_called:
		_waves_called = due
		Sfx.play(&"slam", global_position)
		stun(0.8)
		Game.spawn_wave(5, 4)


func on_bullet_hit(bullet: Node, point: Vector3, _normal: Vector3) -> bool:
	hurt(1, point, (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO)
	return false


func on_laser(direction: Vector3) -> void:
	hurt(3, global_position + Vector3.UP * 1.5, direction)


func on_explosion(centre: Vector3) -> void:
	hurt(4, global_position + Vector3.UP * 1.5, global_position - centre)


func on_stabbed(direction: Vector3) -> void:
	hurt(1, global_position + Vector3.UP * 1.3, direction)


func on_rammed(direction: Vector3) -> void:
	hurt(2, global_position + Vector3.UP * 1.3, direction)


func _take_blunt(_damage: int, _stun_time: float, _push: Vector3) -> void:
	Sfx.play(&"punch", global_position)


func _physics_process(delta: float) -> void:
	super(delta)
	if not alive or stunned:
		_slam_clock = -1.0
		winding_up = false
		return
	var wd: float = TimeManager.world_delta(delta)
	if _slam_clock < 0.0:
		if dist_to_player <= T.brute_slam_range:
			_slam_clock = 0.0
			winding_up = true
		return
	_slam_clock += wd
	desired_velocity = Vector3.ZERO
	if _slam_clock >= 0.7:
		_slam_clock = -1.0
		winding_up = false
		Sfx.play(&"slam", global_position)
		Shatter.burst(Game.entities_root(self), global_position - global_transform.basis.z * 1.4, 14, Mats.floor_mat(),
			Vector3(0.8, 0.05, 0.8), Vector3.UP * 3.0, 0.16)
		var p: Player = get_player()
		if p != null and p.alive:
			p.fx.shake(0.06)
			if flat_distance_to(p.global_position) <= T.brute_slam_range + 0.7:
				p.hit_from(p.global_position - global_position)


