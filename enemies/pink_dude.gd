class_name PinkDude
extends CharacterBody3D
## An evil pink dude. Everything here runs on world time.

signal died(dude: PinkDude)
signal state_changed(state_name: StringName)

const T: Tuning = preload("res://data/tuning.tres")
const TURN_RATE: float = 9.0

var armed_at_spawn: bool = true
var seeks_weapons: bool = true
var hp: int = 3
var alive: bool = true
var weapon: Pistol = null
## Visual and collision size multiplier. The Director is bigger.
var body_scale: float = 1.0

# Senses. Tests set `sense_override` and write these directly.
var sense_override: bool = false
var can_see_player: bool = false
var dist_to_player: float = INF
var alerted: bool = false

# Flags the states drive and the body animates from.
var desired_velocity: Vector3 = Vector3.ZERO
var aiming: bool = false
var stunned: bool = false
var winding_up: bool = false
var hiding: bool = false

## Where on the ring around the player this dude likes to stand.
var flank_angle: float = 0.0
var ring_distance: float = 8.0

var state: DudeState
var state_name: StringName = &""
var agent: NavigationAgent3D
var parts: Dictionary[StringName, Node3D] = {}

var _states: Dictionary[StringName, DudeState] = {}
var _laser: MeshInstance3D
var _walk_phase: float = 0.0
var _aim_raise: float = 0.0


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = 4
	collision_mask = 1 | 32
	floor_snap_length = 0.3
	hp = T.dude_hp
	flank_angle = randf() * TAU
	ring_distance = randf_range(T.dude_ring_min, T.dude_ring_max)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35 * body_scale
	capsule.height = 1.8 * body_scale
	shape.shape = capsule
	shape.position.y = 0.9 * body_scale
	add_child(shape)

	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	agent.avoidance_enabled = false
	add_child(agent)

	parts = BodyBuilder.build(self)
	parts[&"root"].scale = Vector3.ONE * body_scale
	_build_laser()

	_states = {
		&"idle": DudeIdle.new(), &"alert": DudeAlert.new(), &"approach": DudeApproach.new(),
		&"aim": DudeAim.new(), &"fire": DudeFire.new(), &"reposition": DudeReposition.new(),
		&"stunned": DudeStunned.new(), &"disarmed": DudeDisarmed.new(), &"dead": DudeDead.new(),
	}
	for s: DudeState in _states.values():
		s.dude = self

	if armed_at_spawn:
		var pistol: Pistol = Pistol.create()
		pistol.attach_to(parts[&"hand"])
		weapon = pistol
	else:
		seeks_weapons = false
	change_state(&"idle")


func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, 1.0)
	mesh.material = Mats.pink_trail()
	_laser.mesh = mesh
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.top_level = true
	_laser.visible = false
	add_child(_laser)


# ---------------------------------------------------------------- tuning hooks

func aim_time() -> float:
	return T.dude_aim_time


func reposition_time() -> float:
	return maxf(0.1, T.dude_cadence - T.dude_aim_time)


func move_speed() -> float:
	return T.dude_run_speed if state_name == &"reposition" else T.dude_speed


func seeks_cover() -> bool:
	return true


# ---------------------------------------------------------------- frame loop

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var wd: float = TimeManager.world_delta(delta)
	if not sense_override:
		sense()
	tick(wd)

	var rate: float = wd / delta if delta > 0.0 else 0.0
	var push: Vector3 = _separation()
	velocity.x = (desired_velocity.x + push.x) * rate
	velocity.z = (desired_velocity.z + push.z) * rate
	velocity.y = 0.0 if is_on_floor() else -4.0 * rate
	move_and_slide()
	_animate(wd)


func tick(wd: float) -> void:
	if state == null or not alive:
		return
	state.time += wd
	var next: StringName = state.update(wd)
	if next != &"":
		change_state(next)


func change_state(next: StringName) -> void:
	if state != null:
		state.exit()
	state = _states[next]
	state_name = next
	state.time = 0.0
	state.enter()
	state_changed.emit(next)


# ---------------------------------------------------------------- senses

func get_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func player_position() -> Vector3:
	var p: Player = get_player()
	return p.global_position if p != null else global_position


func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.55 * body_scale, 0)


func sense() -> void:
	var p: Player = get_player()
	if p == null or not p.alive:
		can_see_player = false
		dist_to_player = INF
		return
	dist_to_player = flat_distance_to(p.global_position)
	can_see_player = false
	if dist_to_player > T.dude_sight:
		return
	if not alerted:
		# Unaware dudes only notice what is in front of them, or very close.
		var to_player: Vector3 = (p.global_position - global_position).normalized()
		var facing: Vector3 = -global_transform.basis.z
		if facing.dot(to_player) < 0.2 and dist_to_player > 5.0:
			return
	can_see_player = Sight.is_clear(get_world_3d().direct_space_state, eye_position(), p.chest_position())


func hear(_from: Vector3) -> void:
	alerted = true


func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


# ---------------------------------------------------------------- movement

## Pushes away from dudes that are too close, so a squad spreads out instead of stacking.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other: PinkDude = node as PinkDude
		if other == null or other == self or not other.alive:
			continue
		var away := Vector3(global_position.x - other.global_position.x, 0, global_position.z - other.global_position.z)
		var d: float = away.length()
		if d < T.dude_separation_radius and d > 0.01:
			push += away / d * (1.0 - d / T.dude_separation_radius)
	return push * T.dude_separation_push


func _nav_ready() -> bool:
	var map: RID = agent.get_navigation_map()
	return map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0


## The spot this dude heads for: its own place on a ring around the player. Once it is
## about that close it goes straight for the player so it always ends up with a line of sight.
func approach_point() -> Vector3:
	var target: Vector3 = player_position()
	if dist_to_player <= ring_distance + 1.5 or not _nav_ready():
		return target
	var wish: Vector3 = target + Vector3(cos(flank_angle), 0, sin(flank_angle)) * ring_distance
	return NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), wish)


func set_nav_target(point: Vector3) -> void:
	agent.target_position = point


func move_along_path(wd: float) -> void:
	if agent.is_navigation_finished():
		desired_velocity = Vector3.ZERO
		return
	var next: Vector3 = agent.get_next_path_position()
	var flat := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if flat.length() < 0.05:
		desired_velocity = Vector3.ZERO
		return
	desired_velocity = flat.normalized() * move_speed()
	face_toward(global_position + flat, wd)


func face_toward(point: Vector3, wd: float) -> void:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length() < 0.01:
		return
	var target_yaw: float = atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, TURN_RATE * wd))


## Between shots: run to the nearest spot the player cannot see. If there is none, sidestep.
func pick_reposition_target() -> void:
	hiding = false
	var p: Player = get_player()
	if seeks_cover() and p != null and _nav_ready():
		var map: RID = agent.get_navigation_map()
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var best := Vector3.INF
		var best_dist: float = INF
		# Three rings of sixteen. A pillar's shadow is only a metre or two wide, so sparse
		# random samples kept missing it.
		var jitter: float = randf() * TAU
		for i: int in 48:
			var angle: float = TAU * (i % 16) / 16.0 + jitter
			var radius: float = T.dude_cover_search_radius * (1.0 + i / 16) / 3.0
			var spot: Vector3 = NavigationServer3D.map_get_closest_point(map,
				global_position + Vector3(cos(angle), 0, sin(angle)) * radius)
			if absf(spot.y - global_position.y) > 1.0:
				continue  # the top of a desk or pillar
			if Sight.is_clear(space, spot + Vector3(0, 1.55 * body_scale, 0), p.chest_position()):
				continue
			var d: float = spot.distance_to(global_position)
			if d < best_dist:
				best_dist = d
				best = spot
		if best.is_finite():
			hiding = true
			set_nav_target(best)
			return
	var side: Vector3 = global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0)
	var wish: Vector3 = global_position + side * randf_range(1.5, 3.0) - global_transform.basis.z * randf_range(-1.0, 1.5)
	if _nav_ready():
		wish = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), wish)
	set_nav_target(wish)


# ---------------------------------------------------------------- weapons

func has_weapon() -> bool:
	return weapon != null and is_instance_valid(weapon)


func muzzle() -> Vector3:
	return global_position + Vector3(0, 1.4 * body_scale, 0) - global_transform.basis.z.normalized() * 0.55 * body_scale


func shoot() -> void:
	if not has_weapon():
		return
	var p: Player = get_player()
	var target: Vector3 = p.chest_position() if p != null else muzzle() - global_transform.basis.z
	var origin: Vector3 = muzzle()
	var dir: Vector3 = (target - origin).normalized()
	var spread: float = deg_to_rad(T.dude_spread_deg)
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	if right.length() > 0.5:
		dir = dir.rotated(right, randf_range(-spread, spread))
	weapon.cooldown_left = 0.0
	weapon.fire(origin, dir, self, false)
	Game.emit_noise(origin, T.dude_hearing)


func find_free_pistol() -> Pistol:
	var best: Pistol = null
	var best_dist: float = T.dude_seek_weapon_dist
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		var pistol: Pistol = node as Pistol
		if pistol == null or pistol.state != Pickup.State.RESTING or pistol.ammo <= 0:
			continue
		var d: float = flat_distance_to(pistol.global_position)
		if d < best_dist:
			best_dist = d
			best = pistol
	return best


func take_weapon(pistol: Pistol) -> void:
	pistol.attach_to(parts[&"hand"])
	weapon = pistol


func disarm() -> void:
	if not has_weapon():
		return
	var pistol: Pistol = weapon
	weapon = null
	pistol.ammo = mini(pistol.ammo, T.enemy_drop_ammo)
	pistol.pop_up(global_position + Vector3(0, 1.5, 0) - global_transform.basis.z * 0.4, player_position())


func land_punch() -> void:
	var p: Player = get_player()
	if p != null and p.alive and dist_to_player <= T.dude_punch_range + 0.5:
		Sfx.play(&"punch", global_position)
		p.die()


# ---------------------------------------------------------------- damage

func stun(duration: float) -> void:
	if not alive:
		return
	(_states[&"stunned"] as DudeStunned).duration = duration
	change_state(&"stunned")


func on_bullet_hit(_bullet: Node, point: Vector3, _normal: Vector3) -> void:
	var from_dir: Vector3 = Vector3.ZERO
	if _bullet is Bullet:
		from_dir = (_bullet as Bullet).direction
	die(point, from_dir)


func on_thrown_hit(item: Pickup) -> void:
	_take_blunt(T.throw_damage, T.throw_stun, item.velocity.normalized())


func on_punched(by: Node, _at: Vector3) -> void:
	var dir: Vector3 = Vector3.ZERO
	if by is Node3D:
		dir = (global_position - (by as Node3D).global_position).normalized()
	_take_blunt(1, T.throw_stun * 0.5, dir)


func _take_blunt(damage: int, stun_time: float, push: Vector3) -> void:
	if not alive:
		return
	hp -= damage
	Sfx.play(&"punch", global_position)
	if hp <= 0:
		die(global_position + Vector3(0, 1.1, 0), push)
		return
	disarm()
	stun(stun_time)


func die(_at: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO) -> void:
	if not alive:
		return
	alive = false
	if has_weapon():
		var pistol: Pistol = weapon
		weapon = null
		pistol.ammo = mini(pistol.ammo, T.enemy_drop_ammo)
		pistol.drop(global_position + Vector3(0, 1.2, 0))
	change_state(&"dead")
	collision_layer = 0
	collision_mask = 0
	_laser.visible = false
	Shatter.burst(Game.entities_root(self), global_position + Vector3(0, 1.0 * body_scale, 0), 24, Mats.pink(),
		Vector3(0.25, 0.8, 0.2) * body_scale, push * 4.0, 0.2 * body_scale)
	Sfx.play(&"shatter", global_position)
	TimeManager.hit_pause(0.05)
	died.emit(self)
	queue_free()


# ---------------------------------------------------------------- looks

func _animate(wd: float) -> void:
	var moving: float = clampf(desired_velocity.length() / maxf(move_speed(), 0.01), 0.0, 1.0)
	_walk_phase += wd * 7.5 * moving
	var swing: float = sin(_walk_phase) * 0.7 * moving
	parts[&"leg_l"].rotation.x = swing
	parts[&"leg_r"].rotation.x = -swing
	parts[&"arm_l"].rotation.x = -swing * 0.8

	var raise_target: float = 1.0 if (aiming or winding_up) else 0.0
	_aim_raise = move_toward(_aim_raise, raise_target, wd * 5.0)
	parts[&"arm_r"].rotation.x = lerpf(swing * 0.8, PI * 0.5, _aim_raise)
	parts[&"root"].rotation.x = lerpf(parts[&"root"].rotation.x, 0.45 if stunned else 0.0, minf(1.0, wd * 10.0))

	_laser.visible = aiming and has_weapon()
	if _laser.visible:
		var from: Vector3 = muzzle()
		var p: Player = get_player()
		var to: Vector3 = p.chest_position() if p != null else from - global_transform.basis.z * 5.0
		var length: float = from.distance_to(to)
		if length > 0.1:
			_laser.global_position = (from + to) * 0.5
			_laser.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
			_laser.scale = Vector3(1, 1, length)
