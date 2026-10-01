class_name TitleStage
extends Node3D
## What is behind the main menu: the white room, one glass capsule with the agent turning
## slowly inside it with a pistol in his hand, and three pink dudes hammering on the glass
## trying to get at him.
##
## It owns its own camera, because at the title there is no level and so no player to look
## through. Everything here runs on real time: it keeps turning while the menu sits there.

const RADIUS: float = 0.78
const HEIGHT: float = 2.45
const SPIN: float = 0.5
const CAPSULE := Vector3(2.30, 0.0, 0.0)

var _figure: Humanoid
var _gun: Gun
var _camera: Camera3D
var _angle: float = PI      # facing the camera to begin with, not showing his back
var _clock: float = 0.0
## The dudes outside: where each one stands, how fast he swings and where in the swing he is.
var _dudes: Array[Humanoid] = []
var _dude_at: Array[Vector3] = []
var _dude_rate: PackedFloat32Array = PackedFloat32Array()
var _dude_phase: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_room()
	_build_capsule()
	_build_agent()
	_build_the_mob()

	_camera = Camera3D.new()
	_camera.fov = 46.0
	# Off to the right of the menu text, looking slightly down at the capsule. Aimed before it
	# is in the tree, so it has to be `look_at_from_position`.
	_camera.look_at_from_position(CAPSULE + Vector3(0.60, 2.35, 6.60),
		CAPSULE + Vector3(-0.30, 1.15, 0.0), Vector3.UP)
	add_child(_camera)
	_camera.current = true


## The camera goes back to the game when the menu leaves.
func release() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.current = false


## And comes back when the menu does, after a run has been quit out of.
func show_again() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.current = true


## The same white room the game is played in: pale floor, pale walls, plenty of light.
func _build_room() -> void:
	_slab(Vector3(26, 0.2, 26), Vector3(0, -0.1, 0), Mats.floor_mat())
	_slab(Vector3(26, 6.0, 0.3), Vector3(0, 3.0, -5.0), Mats.wall())
	_slab(Vector3(0.3, 6.0, 12.0), Vector3(-6.5, 3.0, 1.0), Mats.wall())
	_slab(Vector3(0.3, 6.0, 12.0), Vector3(7.5, 3.0, 1.0), Mats.wall())
	_slab(Vector3(26, 0.3, 26), Vector3(0, 6.0, 0), Mats.wall())

	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	key.shadow_enabled = true
	add_child(key)

	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.86, 0.94)
	fill.light_energy = 2.2
	fill.omni_range = 13.0
	fill.position = CAPSULE + Vector3(0.6, 3.2, 2.6)
	add_child(fill)


func _slab(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	add_child(mi)


func _build_capsule() -> void:
	_tube(RADIUS + 0.12, 0.26, CAPSULE + Vector3(0, 0.13, 0), Mats.gunmetal())
	_tube(RADIUS + 0.14, 0.04, CAPSULE + Vector3(0, 0.28, 0), Mats.pink_bright())
	_tube(RADIUS + 0.08, 0.18, CAPSULE + Vector3(0, HEIGHT + 0.09, 0), Mats.gunmetal())
	_tube(RADIUS - 0.14, 0.04, CAPSULE + Vector3(0, HEIGHT - 0.02, 0), Mats.pink_bright())
	_tube(RADIUS, HEIGHT - 0.3, CAPSULE + Vector3(0, 0.3 + (HEIGHT - 0.3) * 0.5, 0), Mats.glass())
	for i: int in 4:
		var rib := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, HEIGHT - 0.26, 0.05)
		box.material = Mats.gunmetal()
		rib.mesh = box
		rib.position = CAPSULE + Vector3(0, HEIGHT * 0.5 + 0.14, 0) \
			+ Vector3(cos(i * PI * 0.5 + 0.78), 0, sin(i * PI * 0.5 + 0.78)) * (RADIUS + 0.02)
		add_child(rib)


func _tube(radius: float, height: float, at: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	add_child(mi)


## The agent: dark suit, shades, a pistol held across his chest.
func _build_agent() -> void:
	# Black all over, the same as the player's body in the game. Only the shades mark him out.
	_figure = Humanoid.create(self, Mats.black(), 1.0)
	_figure.set_sunglasses(true)
	_gun = Pistol.create()
	_gun.state = Pickup.State.HELD
	add_child(_gun)


## Three of them round the capsule, swinging at the glass. Plain Humanoids, not PinkDudes:
## there is no level and no navmesh at the title, and they have nowhere to walk to anyway.
func _build_the_mob() -> void:
	# All three on the side the camera is on, clear of the glass: behind it they read as being
	# inside the capsule.
	var places: Array[Vector3] = [
		CAPSULE + Vector3(-1.05, 0.0, 1.15),
		CAPSULE + Vector3(1.32, 0.0, 0.80),
		CAPSULE + Vector3(1.55, 0.0, -0.45),
	]
	var rates := PackedFloat32Array([5.6, 4.7, 6.3])
	for i: int in places.size():
		var dude: Humanoid = Humanoid.create(self, Mats.pink(), 1.0)
		dude.set_sunglasses(true)
		_dudes.append(dude)
		_dude_at.append(places[i])
		_dude_rate.append(rates[i])
		_dude_phase.append(float(i) * 1.3)


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_angle = wrapf(_angle + delta * SPIN, 0.0, TAU)
	var stand := Transform3D(Basis(Vector3.UP, _angle), global_position + CAPSULE + Vector3(0, 0.30, 0))
	var joints: PackedVector3Array = Humanoid.to_world(
		Humanoid.pose(0.0, 0.0, 0.95, 0.0, 0.0), stand, 1.0)
	_figure.apply(joints)
	if _gun != null and is_instance_valid(_gun):
		_gun.global_transform = _hand_of(joints) * Transform3D(Basis(Vector3.RIGHT, -1.35), Vector3.ZERO)
	_swing_at_the_glass()


## Where a pistol sits in the right hand: the palm, pointed the way the forearm runs.
func _hand_of(joints: PackedVector3Array) -> Transform3D:
	var wrist: Vector3 = joints[Humanoid.index_of(&"wrist_r")]
	var hand: Vector3 = joints[Humanoid.index_of(&"hand_r")]
	var forward: Vector3 = (wrist - joints[Humanoid.index_of(&"elbow_r")]).normalized()
	var up: Vector3 = Vector3.UP if absf(forward.y) < 0.95 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(forward, up), wrist.lerp(hand, 0.5))


## Each one leans in and hammers on the glass, out of step with the others.
func _swing_at_the_glass() -> void:
	for i: int in _dudes.size():
		var here: Vector3 = _dude_at[i]
		var to_glass: Vector3 = (CAPSULE - here)
		var facing: float = atan2(-to_glass.x, -to_glass.z)
		var beat: float = sin(_clock * _dude_rate[i] + _dude_phase[i])
		# The swing: the arm comes up and down, the body rocks forward with it.
		var raise: float = 0.80 + beat * 0.20
		var rock: float = maxf(0.0, beat) * 0.35
		var at := Transform3D(Basis(Vector3.UP, facing), global_position + here + Vector3(0, rock * 0.1, 0))
		# `reach_straight` throws both arms out in front of him: that is the shape of a man
		# beating on a pane of glass rather than aiming a gun at it.
		_dudes[i].apply(Humanoid.to_world(
			Humanoid.pose(0.0, 0.0, raise, raise * 0.9, rock, true), at, 1.0))
