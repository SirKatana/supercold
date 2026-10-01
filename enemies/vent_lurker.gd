class_name VentLurker
extends CharacterBody3D
## Green, and he lives in the ducts. He comes down the tunnel after you, flat on his belly,
## arms out, and **swings at you** when he gets there. He does not hold you still -- being
## pinned while the screen shook was unreadable -- so the fight in a duct is a fight: punch
## him, shoot him, or back out.
##
## He counts toward clearing the floor like anybody else, so a duct is not optional any more.

signal grabbed(player: Player)
signal let_go
signal died

enum Mode { WAITING, COMING, SWINGING, DEAD }

const T: Tuning = preload("res://data/tuning.tres")
## Small enough that lying flat he fits the width of a duct. A full-sized man laid out in a
## 1.1 m tunnel has his head and his heels through the walls.
const BODY_SCALE: float = 0.68

var mode: Mode = Mode.WAITING
var alive: bool = true
var hp: int = 2
var skin: Humanoid
var joints: PackedVector3Array = []

## Seconds of windup left before the blow lands, and until he may swing again.
var _swing_left: float = 0.0
var _rest_left: float = 0.0
var _crawl: float = 0.0
var _agent: NavigationAgent3D
var _home: Vector3


func _ready() -> void:
	add_to_group(&"lurkers")
	# Deliberately NOT in the `enemies` group: half the game casts the members of that group to
	# PinkDude. He blocks the floor clear through `Game.count_other_enemy()` instead.
	collision_layer = 4          # an enemy to every bullet, punch, blade and blast
	collision_mask = 1
	hp = T.lurker_hp
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 0.80        # he is never anything but flat
	shape.shape = capsule
	shape.position.y = 0.40
	add_child(shape)
	skin = Humanoid.create(self, Mats.lurker(), BODY_SCALE)
	skin.set_sunglasses(false)
	_agent = NavigationAgent3D.new()
	_agent.avoidance_enabled = false
	add_child(_agent)
	_home = global_position
	_pose(0.0)


func voice_name_id() -> StringName:
	return &"name_lurker"


func player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


## True while the player is in the ducts with him.
func _player_in_the_ducts(p: Player) -> bool:
	return p != null and p.alive and p.crawling and VentDuct.inside(Game.data, p.global_position)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var wd: float = TimeManager.world_delta(delta)
	var p: Player = player()
	match mode:
		Mode.WAITING:
			# He waits where he is, and only stirs when somebody is in the duct with him.
			if _player_in_the_ducts(p) and global_position.distance_to(p.global_position) <= T.lurker_sense:
				mode = Mode.COMING
				Sfx.play(&"choke", global_position)
		Mode.COMING:
			if not _player_in_the_ducts(p):
				# He will not leave the ducts. He goes back and waits.
				if global_position.distance_to(_home) > 0.4:
					_crawl_toward(_home, wd, delta)
				else:
					mode = Mode.WAITING
			elif global_position.distance_to(p.global_position) <= T.lurker_grab_range and _rest_left <= 0.0:
				_start_swing(p)
			else:
				_rest_left = maxf(0.0, _rest_left - wd)
				_crawl_toward(p.global_position, wd, delta)
		Mode.SWINGING:
			if p == null or not p.alive:
				mode = Mode.COMING
			else:
				_face(p.global_position, wd)
				_swing_left -= wd
				_crawl += delta * 7.0
				if _swing_left <= 0.0:
					# The blow lands if you are still in front of him when it does.
					if global_position.distance_to(p.global_position) <= T.lurker_grab_range + 0.35:
						p.killed_by_the("THE THING IN THE VENTS")
					else:
						Sfx.play(&"punch", global_position)
					mode = Mode.COMING
					_rest_left = T.lurker_swing_rest
	_pose(wd)


func _facing_player(p: Player) -> Vector3:
	var flat: Vector3 = p.global_position - global_position
	flat.y = 0.0
	return flat.normalized() if flat.length() > 0.01 else global_transform.basis.z


## He draws back for a moment before he swings, which is the window to hit him first.
func _start_swing(p: Player) -> void:
	mode = Mode.SWINGING
	_swing_left = T.lurker_windup
	Sfx.play(&"choke", global_position)
	p.fx.shake(0.18)
	grabbed.emit(p)


func _release() -> void:
	var p: Player = player()
	if p != null and p.held_by == self:
		p.held_by = null
	if alive:
		mode = Mode.COMING
	let_go.emit()


func _crawl_toward(target: Vector3, wd: float, delta: float) -> void:
	_agent.target_position = target
	var next: Vector3 = _agent.get_next_path_position()
	var flat := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if flat.length() < 0.05:
		flat = Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() < 0.05 or delta <= 0.0:
		return
	_face(global_position + flat, wd)
	velocity = flat.normalized() * T.lurker_speed * (wd / delta)
	move_and_slide()
	_hug_the_tunnel()
	_crawl += wd * 9.0


func _face(point: Vector3, step: float) -> void:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length() < 0.01:
		return
	var wanted: float = atan2(-flat.x, -flat.z)
	# In a duct he lies along the tunnel, never across it: he is longer than it is wide.
	var along: Vector3 = _tunnel_heading(flat)
	if along != Vector3.ZERO:
		wanted = atan2(-along.x, -along.z)
	rotation.y = lerp_angle(rotation.y, wanted, minf(1.0, 9.0 * step))


## Which way the tunnel runs where he is, turned to whichever end he is heading for. Zero if
## he is not in a duct, or if it is an open junction, where he can lie any way he likes.
func _tunnel_heading(toward: Vector3) -> Vector3:
	if Game.data == null:
		return Vector3.ZERO
	var here: Vector2i = Game.data.cell_of(global_position)
	if not VentDuct.inside(Game.data, global_position):
		return Vector3.ZERO
	var best: Vector3 = Vector3.ZERO
	var best_dot: float = -2.0
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not VentDuct.connects_for_lurker(Game.data, here, step):
			continue
		var way := Vector3(step.x, 0, step.y)
		var dot: float = way.dot(toward.normalized())
		if dot > best_dot:
			best_dot = dot
			best = way
	return best


## Keeps him off the walls: in a straight length of duct he rides the centre line.
func _hug_the_tunnel() -> void:
	if Game.data == null or not VentDuct.inside(Game.data, global_position):
		return
	var here: Vector2i = Game.data.cell_of(global_position)
	var centre: Vector3 = Game.data.cell_center(here, global_position.y)
	var opens_x: bool = VentDuct.connects_for_lurker(Game.data, here, Vector2i(1, 0)) \
		or VentDuct.connects_for_lurker(Game.data, here, Vector2i(-1, 0))
	var opens_z: bool = VentDuct.connects_for_lurker(Game.data, here, Vector2i(0, 1)) \
		or VentDuct.connects_for_lurker(Game.data, here, Vector2i(0, -1))
	if opens_x and not opens_z:
		global_position.z = lerpf(global_position.z, centre.z, 0.3)
	elif opens_z and not opens_x:
		global_position.x = lerpf(global_position.x, centre.x, 0.3)


## Flat out, arms reaching, dragging himself along.
func _pose(_wd: float) -> void:
	var reach: float = 0.85 + 0.15 * sin(_crawl)
	var local: PackedVector3Array = Humanoid.pose(_crawl, 0.7, reach, 0.85 - 0.15 * sin(_crawl), 0.0, true, 0.0, 1.0)
	var flat := Basis(Vector3.RIGHT, -1.35)      # face down, belly to the floor
	for i: int in local.size():
		local[i] = flat * local[i] + Vector3(0, 0.62, 0)
	joints = Humanoid.to_world(local, global_transform, BODY_SCALE)
	skin.apply(joints)


# ---------------------------------------------------------------- hurting him

func on_bullet_hit(_bullet: Node, point: Vector3, normal: Vector3) -> bool:
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 3, Mats.lurker(), Vector3.ONE * 0.02, normal * 1.5, 0.03)
	_hurt(T.lurker_hp)
	return false


func on_punched(_by: Node, _at: Vector3) -> void:
	_hurt(1)


func on_thrown_hit(_item: Pickup) -> void:
	_hurt(1)


func on_stabbed(_direction: Vector3) -> void:
	_hurt(T.lurker_hp)


func on_laser(_direction: Vector3) -> void:
	_hurt(T.lurker_hp)


func on_explosion(_centre: Vector3) -> void:
	_hurt(T.lurker_hp)


## Hurt him from outside: tests and anything that wants him gone without a bullet.
func take_damage(amount: int) -> void:
	_hurt(amount)


func _hurt(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	if hp > 0:
		Sfx.play(&"punch", global_position)
		return
	alive = false
	mode = Mode.DEAD
	collision_layer = 0
	_release()
	Game.count_enemy_down(self)
	Ragdoll.spawn(Game.entities_root(self), joints, BODY_SCALE, Vector3.UP * 1.5, Mats.lurker(), 1.0)
	Sfx.play(&"shatter", global_position)
	died.emit()
	queue_free()


func display_name() -> String:
	return "THE THING IN THE VENTS"
