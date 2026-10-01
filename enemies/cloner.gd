class_name Cloner
extends PinkDude
## Mint white, unarmed, and he will not come near you. He backs away and makes copies of
## himself: pale, see-through, one-hit rushers who cannot copy anything. He can have
## `cloner_at_once` out at a time and `cloner_budget` in all.
##
## Kill him and every copy goes with him, so a room full of them is always one problem.

signal cloned(copy: Cloner)

## A copy. Copies never make copies.
var is_copy: bool = false
var master: Cloner = null
var copies: Array[Cloner] = []
var made: int = 0

var _clock: float = 0.0
var _appearing: float = 0.0


func _ready() -> void:
	armed_at_spawn = false
	body_scale = 1.0 if not is_copy else 0.96
	body_material = Mats.clone_copy() if is_copy else Mats.cloner()
	super()
	hp = 1 if is_copy else 2
	seeks_weapons = false
	_clock = T.cloner_interval * 0.5
	if is_copy:
		add_to_group(&"clones")
		_appearing = T.cloner_spawn_seconds


func voice_name_id() -> StringName:
	return &"name_cloner"


func wears_shades() -> bool:
	return not is_copy      # a copy is a copy of the man, not of what he is wearing


func seeks_cover() -> bool:
	return false


## A copy fights. The man who makes them never does.
func fights_hand_to_hand() -> bool:
	return is_copy


func move_speed() -> float:
	return T.clone_speed if is_copy else T.cloner_speed


## He never closes: he keeps the length of a room between you, and the copies do the fighting.
func approach_point() -> Vector3:
	if is_copy:
		return super()
	var away: Vector3 = global_position - player_position()
	away.y = 0.0
	if away.length() < 0.3:
		away = global_transform.basis.z
	var wish: Vector3 = player_position() + away.normalized() * T.cloner_keep_away
	return NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), wish) if _nav_ready() else wish


func _physics_process(delta: float) -> void:
	super(delta)
	if not alive:
		return
	var wd: float = TimeManager.world_delta(delta)
	if _appearing > 0.0:
		# A copy fades up out of nothing where he was made.
		_appearing = maxf(0.0, _appearing - wd)
		var t: float = 1.0 - _appearing / T.cloner_spawn_seconds
		skin.scale = Vector3.ONE * lerpf(0.4, 1.0, t)
		return
	if is_copy or not alerted:
		return
	_clock -= wd
	if _clock <= 0.0:
		_clock = T.cloner_interval
		_make_a_copy()


func alive_copies() -> int:
	var n: int = 0
	for c: Cloner in copies:
		if is_instance_valid(c) and c.alive:
			n += 1
	return n


func _make_a_copy() -> void:
	if made >= T.cloner_budget or alive_copies() >= T.cloner_at_once:
		return
	made += 1
	var side: Vector3 = global_transform.basis.x * (1.2 if made % 2 == 0 else -1.2)
	var at: Vector3 = global_position + side
	if _nav_ready():
		at = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), at)
	var copy := Cloner.new()
	copy.name = "Clone"
	copy.is_copy = true
	copy.master = self
	Game.entities_root(self).add_child(copy)
	copy.global_position = at
	copy.alerted = true
	copy.sense_override = sense_override
	Game.count_new_enemy(copy)
	copies.append(copy)
	Shatter.burst(Game.entities_root(self), at + Vector3(0, 1.0, 0), 10, Mats.cloner(), Vector3(0.3, 0.8, 0.3), Vector3.UP * 1.5, 0.05)
	Sfx.play(&"pickup", at)
	cloned.emit(copy)


## The man himself dying takes all of him with it.
func die(at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO, style: StringName = &"ragdoll") -> void:
	var was_alive: bool = alive
	super(at, push, style)
	if is_copy or not was_alive:
		return
	for c: Cloner in copies:
		if is_instance_valid(c) and c.alive:
			Shatter.burst(Game.entities_root(self), c.global_position + Vector3(0, 1.0, 0), 12, Mats.clone_copy(),
				Vector3(0.3, 0.8, 0.3), Vector3.UP * 2.0, 0.06)
			c.die(c.global_position, Vector3.UP * 0.2, &"ice")      # they pop, they do not fall


func display_name() -> String:
	return "THE CLONER"
