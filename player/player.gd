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


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 2
	collision_mask = MASK
	floor_snap_length = 0.2

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

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

	fx = CameraFx.new()
	fx.name = "CameraFx"
	fx.camera = camera
	add_child(fx)
	Game.enemy_killed.connect(_on_enemy_killed)

	hands = Hands.new()
	hands.name = "Hands"
	hands.player = self
	camera.add_child(hands)


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
		var sens: float = Settings.mouse_sensitivity
		rotate_y(deg_to_rad(-motion.relative.x * sens))
		head.rotation.x = clampf(head.rotation.x - deg_to_rad(motion.relative.y * sens), -1.5, 1.5)
		_look_accum_deg += motion.relative.length() * sens


func _physics_process(delta: float) -> void:
	_look_rate = lerpf(_look_rate, _look_accum_deg / delta, 0.5)
	_look_accum_deg = 0.0

	var wish := Vector3.ZERO
	if alive and input_enabled:
		var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		wish = (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized() * T.walk_speed
		if Input.is_action_just_pressed(&"jump") and is_on_floor():
			velocity.y = T.jump_velocity

	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(wish.x, wish.z), T.accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if not is_on_floor():
		velocity.y -= T.gravity * delta
	move_and_slide()

	var real: Vector3 = get_real_velocity()
	TimeManager.report_move(Vector2(real.x, real.z).length() if alive else 0.0)
	TimeManager.report_look(_look_rate if alive else 0.0)


func _on_enemy_killed(_remaining: int) -> void:
	fx.punch_fov(4.0)


func on_bullet_hit(_bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	die()


func die() -> void:
	if not alive or Game.god_mode:
		return
	alive = false
	velocity = Vector3.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(head, ^"position:y", 0.35, 0.35).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(head, ^"rotation:z", 0.6, 0.35)
	died.emit()
