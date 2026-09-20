class_name Zombie
extends PinkDude
## The biter. He waits under the floor, claws his way up when you come close, shambles at
## you with his arms out, lunges the last few metres, and bites. He does not breathe, so
## gas does nothing. He is not counted toward clearing the floor until he is up.

signal risen

var buried: bool = true
var rising: bool = false

var _rise: float = 0.0
var _surface: Vector3


func _ready() -> void:
	armed_at_spawn = false
	body_material = Mats.zombie()
	super()
	seeks_weapons = false
	remove_from_group(&"enemies")
	add_to_group(&"buried")
	collision_layer = 0
	collision_mask = 0
	skin.visible = false
	alerted = true


func voice_name_id() -> StringName:
	return &"name_zombie"


## He came out of the floor. He lost his a long time ago.
func wears_shades() -> bool:
	return false


func seeks_cover() -> bool:
	return false


func can_choke() -> bool:
	return false


func move_speed() -> float:
	return T.zombie_lunge if dist_to_player <= T.zombie_lunge_distance else T.zombie_shamble


func punch_range() -> float:
	return T.zombie_bite_range


func punch_windup() -> float:
	return 0.34


func punch_sound() -> StringName:
	return &"bite"


## Arms out in front, always.
func arm_raise_floor() -> float:
	return 0.0 if buried and not rising else 0.92


func aim_left_amount() -> float:
	return arm_raise_floor()


func _physics_process(delta: float) -> void:
	if not buried:
		super(delta)
		return
	var wd: float = TimeManager.world_delta(delta)
	if not rising:
		var p: Player = get_player()
		if p != null and p.alive and Game.state == Game.State.PLAYING \
				and flat_distance_to(p.global_position) <= T.zombie_wake_distance:
			_start_rising()
		return
	_rise = minf(1.0, _rise + wd / T.zombie_rise_seconds)
	var ease_t: float = 1.0 - pow(1.0 - _rise, 2.0)
	global_position = _surface + Vector3.DOWN * (1.0 - ease_t) * 1.75
	face_toward(player_position(), wd)
	_animate(wd)
	if _rise >= 1.0:
		_finish_rising()


func _start_rising() -> void:
	rising = true
	_surface = global_position
	global_position = _surface + Vector3.DOWN * 1.75
	skin.visible = true
	Sfx.play(&"rise", _surface)
	Shatter.burst(Game.entities_root(self), _surface + Vector3.UP * 0.1, 16, Mats.floor_mat(), Vector3(0.4, 0.05, 0.4), Vector3.UP * 2.2, 0.13)


func _finish_rising() -> void:
	buried = false
	rising = false
	global_position = _surface
	collision_layer = 4
	collision_mask = 1 | 32
	remove_from_group(&"buried")
	add_to_group(&"enemies")
	change_state(&"disarmed")
	risen.emit()
	Game.register_risen(self)
