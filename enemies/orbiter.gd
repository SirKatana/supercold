class_name Orbiter
extends PinkDude
## The one who does not come down. He stands on a rock hanging over an open station floor,
## shoots at you across the whole room, and hops to another rock when he has been there long
## enough. There is no getting to him: you shoot him off it from where you are.
##
## He keeps the ordinary dude's brain -- alert, aim, telegraph, fire -- but not its legs. The
## navmesh is on the floor and he never touches it, so `_physics_process` is replaced with
## flight and `desired_velocity` is ignored.

## The rocks he can stand on, handed to him when the floor is built.
var perches: Array[Node3D] = []
## World seconds on one rock before he moves to the next.
var hop_after: float = 5.5
var hop_seconds: float = 2.2

var _perch: Node3D = null
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _hop_left: float = 0.0
var _standing_for: float = 0.0
var _bob: float = 0.0


func _ready() -> void:
	armed_at_spawn = true
	weapon_kind = &"sniper"
	body_scale = 1.0
	body_material = Mats.spacesuit()
	super()
	hp = 2
	seeks_weapons = false
	# He is already looking for you: there is nothing else to do up there.
	alerted = true
	_standing_for = randf() * hop_after


func voice_name_id() -> StringName:
	# He carries a long gun and shoots from across the room: the helper calls him a sniper,
	# which is what he is. Adding a name of his own would need a new voice clip rendered.
	return &"name_sniper"


func seeks_cover() -> bool:
	return false


## Unarmed he still will not come down to swing at anybody.
func fights_hand_to_hand() -> bool:
	return false


func wears_shades() -> bool:
	return false      # the helmet is in the way


## Put him on a rock and give him the rest of them to hop between.
func stand_on(rocks: Array[Node3D], first: int) -> void:
	perches = rocks
	if perches.is_empty():
		return
	_perch = perches[first % perches.size()]
	global_position = _top_of(_perch)
	_to = global_position


func _top_of(rock: Node3D) -> Vector3:
	var lift: float = (rock as Planetoid).radius if rock is Planetoid else 2.0
	return rock.global_position + Vector3.UP * lift


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var wd: float = TimeManager.world_delta(delta)
	gas_clock += wd
	last_slip += wd
	if not sense_override and not frozen:
		sense()
	tick(wd)
	if not frozen:
		_fly(wd)
		_animate(wd)


## Either crossing to the next rock or standing on one, breathing.
func _fly(wd: float) -> void:
	velocity = Vector3.ZERO
	if _hop_left > 0.0:
		_hop_left = maxf(0.0, _hop_left - wd)
		var along: float = 1.0 - _hop_left / hop_seconds
		var eased: float = along * along * (3.0 - 2.0 * along)
		# An arc rather than a straight line: he rises out of one orbit and drops into the next.
		var arc: float = sin(along * PI) * 2.2
		global_position = _from.lerp(_to, eased) + Vector3.UP * arc
		if _hop_left <= 0.0:
			_standing_for = 0.0
		_face_the_player()
		return
	_bob += wd
	global_position = _to + Vector3.UP * sin(_bob * 1.6) * 0.12
	_face_the_player()
	_standing_for += wd
	if _standing_for >= hop_after and perches.size() > 1:
		_hop()


## Off to another rock, preferring one the player is not already staring at.
func _hop() -> void:
	var here: Vector3 = global_position
	var best: Node3D = null
	var best_score: float = -INF
	for rock: Node3D in perches:
		if rock == _perch or not is_instance_valid(rock):
			continue
		var there: Vector3 = _top_of(rock)
		# Somewhere else, but not the whole way across the room every time.
		var score: float = randf() * 6.0 - absf(there.distance_to(here) - 12.0)
		if score > best_score:
			best_score = score
			best = rock
	if best == null:
		return
	_perch = best
	_from = global_position
	_to = _top_of(best)
	_hop_left = hop_seconds
	_standing_for = 0.0


func _face_the_player() -> void:
	var p: Player = get_player()
	if p == null:
		return
	var flat := Vector3(p.global_position.x - global_position.x, 0.0,
		p.global_position.z - global_position.z)
	if flat.length() < 0.05:
		return
	rotation.y = atan2(-flat.x, -flat.z)


## He is above the floor and shooting down it, so the flat distance the others use would say
## he is on top of the player when he is ten metres up. Use the real one.
func sense() -> void:
	super()
	var p: Player = get_player()
	if p != null and p.alive and dist_to_player < INF:
		dist_to_player = global_position.distance_to(p.chest_position())


## Shot off his rock, he falls the rest of the way on his own.
func die(at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO, style: StringName = &"ragdoll") -> void:
	_hop_left = 0.0
	super(at, push, style)
