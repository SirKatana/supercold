class_name HelperCapsule
extends Node3D
## A glass capsule with a red figure turning slowly inside. It waits outside the lift after
## the third death on a floor. Shoot, punch or hit its button to watch an ad; watch enough
## of it and the figure steps out to help for three minutes.

signal hired

const T: Tuning = preload("res://data/tuning.tres")
const RADIUS: float = 0.62
const HEIGHT: float = 2.25

var button: ElevatorButton
var used: bool = false

var _figure: Humanoid
var _glass: MeshInstance3D
var _sign: Label3D
var _angle: float = 0.0
var _waiting_for_ad: bool = false


func _ready() -> void:
	add_to_group(&"helper_capsule")
	_build()
	AdService.finished.connect(_on_ad_finished)


func _tube(radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.material = material
	mi.mesh = mesh
	mi.position = at
	add_child(mi)
	return mi


func _build() -> void:
	_tube(RADIUS + 0.10, 0.22, Vector3(0, 0.11, 0), Mats.polymer())               # plinth
	_tube(RADIUS + 0.12, 0.03, Vector3(0, 0.235, 0), Mats.helper_red())           # glowing ring
	_tube(RADIUS + 0.06, 0.16, Vector3(0, HEIGHT + 0.08, 0), Mats.polymer())      # cap
	_tube(RADIUS - 0.12, 0.03, Vector3(0, HEIGHT - 0.015, 0), Mats.helper_red())  # lamp
	_glass = _tube(RADIUS, HEIGHT - 0.24, Vector3(0, 0.24 + (HEIGHT - 0.24) * 0.5, 0), Mats.glass())
	for i: int in 4:                                                              # four steel ribs
		var rib := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, HEIGHT - 0.2, 0.05)
		box.material = Mats.gunmetal()
		rib.mesh = box
		rib.position = Vector3(cos(i * PI * 0.5 + 0.78), 0, sin(i * PI * 0.5 + 0.78)) * (RADIUS + 0.015) + Vector3(0, HEIGHT * 0.5 + 0.1, 0)
		add_child(rib)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.25, 0.2)
	lamp.light_energy = 0.9
	lamp.omni_range = 4.5
	lamp.shadow_enabled = false
	lamp.position.y = HEIGHT * 0.6
	add_child(lamp)

	# Solid, so nobody walks through it and nothing shoots the figure inside.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS + 0.05
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position.y = HEIGHT * 0.5
	body.add_child(shape)
	add_child(body)

	_figure = Humanoid.create(self, Mats.helper_red(), 0.98)

	# The button stands on a post at the front, which is local -Z.
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.10, 1.25, 0.10)
	post_mesh.material = Mats.gunmetal()
	post.mesh = post_mesh
	post.position = Vector3(0.95, 0.625, -0.55)
	add_child(post)
	button = ElevatorButton.new()
	button.name = "HireButton"
	button.position = Vector3(0.95, 1.22, -0.62)
	add_child(button)
	button.pressed.connect(press)

	_sign = Label3D.new()
	_sign.font_size = 44
	_sign.pixel_size = 0.0046
	_sign.modulate = Color(1.0, 0.35, 0.3)
	_sign.shaded = false
	_sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sign.position = Vector3(0, HEIGHT + 0.55, 0)
	add_child(_sign)
	_refresh_sign()


func _refresh_sign() -> void:
	if used:
		_sign.text = ""      # he is out and talking, the sign would show through his speech bubble
	elif _waiting_for_ad:
		_sign.text = "..."
	else:
		_sign.text = "NEED A HAND?\nHIT THE BUTTON: WATCH AN AD\nHELPER FOR %d:00" % int(T.helper_seconds / 60.0)


func _process(delta: float) -> void:
	# Real time: it should turn while the player stands and looks at it.
	_angle += delta * 0.45
	if _figure.visible:
		var turn := Transform3D(Basis(Vector3.UP, _angle), global_position + Vector3(0, 0.25, 0))
		_figure.apply(Humanoid.to_world(Humanoid.pose(0.0, 0.0, 0.0, 0.0, 0.0), turn, 0.98))
	button.set_lit(not used and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6)


func press() -> void:
	if used or _waiting_for_ad or AdService.showing:
		return
	_waiting_for_ad = true
	_refresh_sign()
	Sfx.play(&"pickup", global_position)
	AdService.show_rewarded()


func _on_ad_finished(rewarded: bool) -> void:
	if not _waiting_for_ad:
		return
	_waiting_for_ad = false
	if rewarded:
		_open()
	_refresh_sign()


func _open() -> void:
	used = true
	_glass.visible = false
	_figure.visible = false
	Shatter.burst(Game.entities_root(self), global_position + Vector3(0, HEIGHT * 0.5, 0), 26, Mats.glass(),
		Vector3(RADIUS, HEIGHT * 0.4, RADIUS), Vector3.UP * 1.5, 0.2)
	Sfx.play(&"shatter", global_position)
	Sfx.play(&"ding", global_position)
	hired.emit()
	Game.hire_helper(global_position - global_transform.basis.z * 1.3, Basis(Vector3.UP, _angle))
