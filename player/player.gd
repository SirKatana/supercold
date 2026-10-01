class_name Player
extends CharacterBody3D
## First-person controller. Runs on real delta: the player is never slowed.

signal died

const T: Tuning = preload("res://data/tuning.tres")
const MASK: int = 1 | 4 | 32  # world, enemies, breakables

var head: Node3D
var camera: Camera3D
var hands: Hands
var fx: CameraFx
var alive: bool = true
var input_enabled: bool = true

var _look_accum_deg: float = 0.0
var _look_rate: float = 0.0
var ragdoll: Ragdoll
## The SWAT shield on the left arm, or null.
var shield: Shield
## Seconds of green screen left. A fart cloud tops it up while the player stands in one.
var in_stink: float = 0.0
## Seconds left of being in deep water (the pool keeps topping it up), and where its surface is.
var in_water: float = 0.0
var water_surface: float = 0.0
## The player's own body: same rig as the dudes. Head and arms are hidden in first person,
## so looking down shows a chest, hips and walking legs.
var body: Humanoid
var body_joints: PackedVector3Array = []
var _walk_phase: float = 0.0
var _death_cam_t: float = 0.0
var _death_cam_from: Transform3D
var _last_hit_direction: Vector3 = Vector3.ZERO


## In a duct he is on his hands and knees: a short capsule, eyes near the floor, and half speed.
## Nothing else changes, so he can still shoot, punch, throw and die in there.
const CRAWL_HEIGHT: float = 0.85
const CRAWL_EYE: float = 0.60
var crawling: bool = false
## Held by something in the dark. He cannot move, but he can still fight.
var held_by: Node3D = null
## Being carried by something that drives his position itself: the helicopter off the roof.
## Gravity and movement are off while it is true, or he falls out of the cabin.
var riding: bool = false
## Knocked back inside by the glove: he is in the air, rolling, and not in charge of it. He
## gets up on his own when he lands.
var tumbling: bool = false
var _tumble_left: float = 0.0
var _tumble_spin: float = 0.0
var _getting_up: float = 0.0

var _crawl_bob: float = 0.0
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 2
	collision_mask = MASK
	floor_snap_length = 0.2

	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = 1.8
	_shape.shape = _capsule
	_shape.position.y = 0.9
	add_child(_shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = T.eye_height
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = Settings.fov
	camera.near = 0.05
	camera.current = true
	head.add_child(camera)

	body = Humanoid.create(self, Mats.arm())
	body.set_group_visible(&"head", false)
	body.set_group_visible(&"arms", false)
	_pose_body(0.0)

	fx = CameraFx.new()
	fx.name = "CameraFx"
	fx.camera = camera
	add_child(fx)
	Game.enemy_killed.connect(_on_enemy_killed)

	hands = Hands.new()
	hands.name = "Hands"
	hands.player = self
	camera.add_child(hands)


## Chest under the surface.
func swimming() -> bool:
	return in_water > 0.0 and global_position.y + 1.05 < water_surface


func head_under_water() -> bool:
	return in_water > 0.0 and camera.global_position.y < water_surface


## Hold jump to rise, let go to sink slowly. At the surface against the wall, jump hauls you out.
func _swim(delta: float) -> void:
	var rising: bool = alive and input_enabled and Input.is_action_pressed(&"jump")
	var target: float = T.swim_up_speed if rising else -T.swim_sink_speed
	velocity.y = move_toward(velocity.y, target, 14.0 * delta)
	var near_surface: bool = global_position.y + T.eye_height > water_surface - 0.25
	if rising and near_surface and is_on_wall():
		velocity.y = T.swim_hop_out


func _pose_body(delta: float) -> void:
	var real: Vector3 = get_real_velocity()
	var moving: float = clampf(Vector2(real.x, real.z).length() / T.walk_speed, 0.0, 1.0)
	_walk_phase += delta * 9.5 * moving
	# Set back a little so the camera sits in front of the chest, not inside it.
	var at := Transform3D(global_transform.basis, global_position + global_transform.basis.z * 0.16)
	body_joints = Humanoid.to_world(Humanoid.pose(_walk_phase, moving, 0.0, 0.0, 0.0), at, 1.0)
	body.apply(body_joints)


func chest_position() -> Vector3:
	return global_position + Vector3(0.0, 1.2, 0.0)


func aim_origin() -> Vector3:
	return camera.global_position


func aim_direction() -> Vector3:
	return -camera.global_transform.basis.z


func _unhandled_input(event: InputEvent) -> void:
	if not alive or not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		# Through the scope the same hand movement must turn the view far less, or it is unusable.
		var sens: float = Settings.mouse_sensitivity * lerpf(1.0, T.scope_fov / Settings.fov, fx.scope_amount)
		rotate_y(deg_to_rad(-motion.relative.x * sens))
		head.rotation.x = clampf(head.rotation.x - deg_to_rad(motion.relative.y * sens), -1.5, 1.5)
		_look_accum_deg += motion.relative.length() * sens


## E at an open duct mouth: climb in, or climb back out into the room beside him. Whatever he
## is carrying comes with him, and he stays on his hands and knees while he is in there.
func use_a_duct() -> bool:
	if Game.data == null or not alive:
		return false
	if VentDuct.inside(Game.data, global_position):
		var room: Vector3 = VentDuct.room_beside(Game.data, global_position)
		if not room.is_finite():
			return false
		global_position = Vector3(room.x, 0.05, room.z)
		_update_crawl()
		Sfx.play(&"pickup", global_position)
		return true
	var mouth: Vector3 = VentDuct.mouth_ahead(Game.data, global_position, -global_transform.basis.z, T.duct_reach)
	if not mouth.is_finite():
		return false
	# Crouch first, then move: a standing capsule will not fit through the hole.
	crawling = true
	_capsule.height = CRAWL_HEIGHT
	_shape.position.y = _capsule.height * 0.5
	head.position.y = CRAWL_EYE
	global_position = Vector3(mouth.x, 0.05, mouth.z)
	velocity = Vector3.ZERO
	Sfx.play(&"pickup", global_position)
	return true


## The camera on hands and knees: a long roll from shoulder to shoulder, a dip with each reach,
## and a little sway. It is the whole of the feeling of being down there, so it is not subtle.
func _crawl_along(delta: float) -> void:
	if not crawling:
		if absf(head.rotation.z) > 0.0001 or absf(_crawl_bob) > 0.0001:
			_crawl_bob = 0.0
			head.rotation.z = move_toward(head.rotation.z, 0.0, delta * 4.0)
			head.position.y = lerpf(head.position.y, T.eye_height, minf(1.0, delta * 8.0))
		return
	var moving: float = clampf(Vector2(velocity.x, velocity.z).length() / T.crawl_speed, 0.0, 1.0)
	_crawl_bob += delta * 5.4 * moving
	head.rotation.z = sin(_crawl_bob) * 0.075 * moving
	head.position.y = CRAWL_EYE + absf(sin(_crawl_bob * 2.0)) * 0.05 * moving
	head.position.x = sin(_crawl_bob) * 0.06 * moving


## Crouches the moment he is in a duct, stands up again when he is out and has the head room.
func _update_crawl() -> void:
	var wants: bool = VentDuct.inside(Game.data, global_position)
	if not wants and crawling:
		var from: Vector3 = global_position + Vector3(0, 0.2, 0)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 1.7, 1)
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			wants = true      # still under something low: stay down
	if wants == crawling:
		return
	crawling = wants
	_capsule.height = CRAWL_HEIGHT if crawling else 1.8
	_shape.position.y = _capsule.height * 0.5
	head.position.y = CRAWL_EYE if crawling else T.eye_height


func _physics_process(delta: float) -> void:
	in_stink = maxf(0.0, in_stink - delta)
	in_water = maxf(0.0, in_water - delta)
	_look_rate = lerpf(_look_rate, _look_accum_deg / delta, 0.5)
	_look_accum_deg = 0.0

	_update_crawl()
	_crawl_along(delta)
	if alive and not tumbling and _over_the_edge():
		_glove_him_back()
	if tumbling:
		_tumble(delta)
		return
	if riding:
		velocity = Vector3.ZERO
		TimeManager.report_move(0.0)
		TimeManager.report_look(0.0)
		return
	var wish := Vector3.ZERO
	if alive and input_enabled and held_by == null:
		var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		wish = (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized() * (T.crawl_speed if crawling else T.walk_speed)
		if swimming():
			wish = wish.normalized() * T.swim_speed if wish.length() > 0.01 else Vector3.ZERO
		elif Input.is_action_just_pressed(&"jump") and is_on_floor():
			velocity.y = T.jump_velocity * Game.jump_scale()

	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(wish.x, wish.z), T.accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if swimming():
		_swim(delta)
	elif not is_on_floor():
		velocity.y -= T.gravity * Game.gravity_scale * delta
	move_and_slide()

	var real: Vector3 = get_real_velocity()
	if alive:
		_pose_body(delta)
	TimeManager.report_move(Vector2(real.x, real.z).length() if alive else 0.0)
	TimeManager.report_look(_look_rate if alive else 0.0)


## Is he off the edge of the building: over a cell that is not floor, or below the deck?
func _over_the_edge() -> bool:
	if Game.data == null or riding:
		return false
	var cell: Vector2i = Game.data.cell_of(global_position)
	var here: String = Game.data.char_at(cell)
	if here == " " or here == "":
		return true
	# Being below the deck is only a problem when it is not meant to be: a pool and a sewer
	# channel are both well under it, and swimming out of one is not falling out of anything.
	if here == "W" or here == "=" or swimming():
		return false
	return global_position.y < -1.2


## A glove swings out of the hole he is going through and puts him back inside.
func _glove_him_back() -> void:
	var inside: Vector3 = _back_towards_the_floor()
	var away: Vector3 = (inside - global_position)
	away.y = 0.0
	if away.length() < 0.1:
		away = global_transform.basis.z
	away = away.normalized()
	# The glove comes out of the hole behind him, so it is swinging the way he is thrown.
	BoxingGlove.swing(Game.entities_root(self), global_position - away * BoxingGlove.REACH * 0.9
		+ Vector3(0, 0.35, 0), away, self)


## The nearest bit of floor he should have stayed on.
func _back_towards_the_floor() -> Vector3:
	var d: LevelData = Game.data
	var here: Vector2i = d.cell_of(global_position)
	var best: Vector3 = d.cell_center(d.player_start, 0.0)
	var best_distance: float = INF
	for radius: int in range(1, 7):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell := here + Vector2i(dx, dy)
				if d.char_at(cell) != ".":
					continue
				var at: Vector3 = d.cell_center(cell, 0.0)
				var distance: float = at.distance_to(global_position)
				if distance < best_distance:
					best_distance = distance
					best = at
		if best_distance < INF:
			return best
	return best


## Taken on the chin: thrown back inside, rolling, and up again where he lands.
func punched_back(direction: Vector3) -> void:
	if tumbling or not alive:
		return
	tumbling = true
	input_enabled = false
	_tumble_left = T.tumble_seconds
	_getting_up = 0.0
	_tumble_spin = 0.0
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	velocity = flat * T.tumble_speed + Vector3.UP * T.tumble_lift
	fx.kick(2.5)
	Sfx.play(&"punch", global_position)


## In the air after the glove: the camera rolls over with him, then he picks himself up.
func _tumble(delta: float) -> void:
	velocity.y -= T.gravity * Game.gravity_scale * delta
	move_and_slide()
	_tumble_left = maxf(0.0, _tumble_left - delta)
	if is_on_floor() and _tumble_left < T.tumble_seconds - 0.15:
		# Down. Getting up takes a moment, and the view comes back level.
		_getting_up += delta
		_tumble_spin = lerpf(_tumble_spin, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		head.position.y = lerpf(head.position.y, T.eye_height, clampf(delta * 5.0, 0.0, 1.0))
		camera.rotation.z = _tumble_spin
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
		if _getting_up >= T.tumble_get_up:
			tumbling = false
			input_enabled = true
			camera.rotation.z = 0.0
			head.position.y = T.eye_height
		return
	# Still flying: roll the view over and drop the head toward the floor.
	_tumble_spin += delta * 7.0
	camera.rotation.z = sin(_tumble_spin) * 1.1
	head.position.y = lerpf(head.position.y, 0.75, clampf(delta * 4.0, 0.0, 1.0))


func bullet_excludes() -> Array[RID]:
	return shield.collider_rids() if shield != null and is_instance_valid(shield) else []


## Killed by something with a direction: a blast, a shove. The body is thrown that way.
func hit_from(direction: Vector3) -> void:
	_last_hit_direction = direction.normalized()
	die()


func _on_enemy_killed(_remaining: int) -> void:
	fx.punch_fov(4.0)


func on_bullet_hit(bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	if bullet is Bullet:
		_last_hit_direction = (bullet as Bullet).direction
	die()


func die() -> void:
	if not alive or Game.god_mode:
		return
	alive = false
	velocity = Vector3.ZERO
	if hands.held != null and is_instance_valid(hands.held):
		hands.held.drop(aim_origin() + aim_direction() * 0.4)
	hands.visible = false
	if shield != null and is_instance_valid(shield):
		shield.release_to_floor(global_position - global_transform.basis.z * 0.7)
		shield = null

	# The body the player never sees while alive goes limp where they stood.
	var push: Vector3 = _last_hit_direction
	if push == Vector3.ZERO:
		push = global_transform.basis.z      # punched from the front: fall backwards
	push = Vector3(push.x, 0.0, push.z).normalized() * 4.6 + Vector3.UP * 1.4
	body.visible = false
	ragdoll = Ragdoll.spawn(Game.entities_root(self), body_joints, 1.0, push, Mats.arm(), T.ragdoll_speed)

	# The camera lets go of the head and pulls back to watch.
	_death_cam_from = camera.global_transform
	camera.top_level = true
	camera.global_transform = _death_cam_from
	fx.set_process(false)
	_death_cam_t = 0.0
	died.emit()


func _process(delta: float) -> void:
	if alive or ragdoll == null or not is_instance_valid(ragdoll):
		return
	_death_cam_t = minf(1.0, _death_cam_t + delta / 1.1)
	var ease_t: float = 1.0 - pow(1.0 - _death_cam_t, 3.0)
	var focus: Vector3 = ragdoll.point(&"chest")
	var back: Vector3 = (_death_cam_from.origin - focus)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else global_transform.basis.z
	var wanted: Vector3 = focus + back * 2.3 + Vector3.UP * 1.5
	# Never let the camera back through a wall.
	var query := PhysicsRayQueryParameters3D.create(focus + Vector3.UP * 0.3, wanted, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		wanted = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.25
	var eye: Vector3 = _death_cam_from.origin.lerp(wanted, ease_t)
	if eye.distance_to(focus) > 0.1:
		camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(focus, Vector3.UP)
