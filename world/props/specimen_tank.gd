class_name SpecimenTank
extends StaticBody3D
## A growing tank in the basement: a glass cylinder of green fluid with something curled up
## inside it, a steel base and a capped top. One of them is always cracked open, its glass gone
## and its fluid across the floor, and that is where the thing you are about to meet came from.

const T: Tuning = preload("res://data/tuning.tres")
const RADIUS: float = 0.62
const HEIGHT: float = 2.45

## An empty tank with the glass broken out of it. The fluid on the floor is a separate puddle.
var cracked: bool = false


static func stand(parent: Node3D, at: Vector3, is_cracked: bool) -> SpecimenTank:
	var tank := SpecimenTank.new()
	tank.cracked = is_cracked
	parent.add_child(tank)
	tank.position = Vector3(at.x, 0.0, at.z)
	tank.rotation.y = randf() * TAU
	return tank


func _ready() -> void:
	add_to_group(&"tanks")
	collision_layer = 1      # world: it is a solid thing to walk round and to hide behind
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshKit.cached(&"tank_cracked" if cracked else &"tank_whole", _model.bind(cracked))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	if not cracked:
		# The fluid glows a little, which is most of the light down here.
		var glow := OmniLight3D.new()
		glow.position.y = HEIGHT * 0.5
		glow.omni_range = 4.5
		glow.light_energy = 0.55
		glow.light_color = Color(0.45, 1.0, 0.65)
		glow.shadow_enabled = false
		add_child(glow)


static func _model(kit: MeshKit, is_cracked: bool) -> void:
	var steel: Material = Mats.steel()
	var dark: Material = Mats.gunmetal()
	var glass: Material = Mats.glass()
	var fluid: Material = Mats.tank_fluid()
	# Base and cap, on every tank.
	kit.tube(RADIUS + 0.10, RADIUS + 0.14, 0.18, Vector3(0, 0.09, 0), dark, false, 16)
	kit.tube(RADIUS + 0.04, RADIUS + 0.04, 0.05, Vector3(0, 0.20, 0), steel, false, 16)
	kit.tube(RADIUS + 0.08, RADIUS + 0.02, 0.22, Vector3(0, HEIGHT - 0.11, 0), dark, false, 16)
	kit.tube(0.09, 0.09, 0.30, Vector3(0, HEIGHT + 0.15, 0), steel, false, 10)      # pipe to the ceiling
	for i: int in 4:                                                                # ribs up the sides
		var angle: float = TAU * i / 4.0
		kit.box(Vector3(0.05, HEIGHT - 0.45, 0.05), Vector3(cos(angle) * (RADIUS + 0.02), HEIGHT * 0.5, sin(angle) * (RADIUS + 0.02)), steel)
	kit.box(Vector3(0.26, 0.16, 0.04), Vector3(0, 0.42, RADIUS + 0.05), Mats.polymer())   # a little gauge panel
	kit.box(Vector3(0.20, 0.10, 0.02), Vector3(0, 0.42, RADIUS + 0.07), Mats.accent())
	if is_cracked:
		# The glass is gone: only the jagged bottom of it is left in the frame.
		for i: int in 9:
			var angle: float = TAU * i / 9.0
			var tall: float = 0.25 + fmod(float(i) * 0.37, 0.45)
			kit.box(Vector3(0.05, tall, 0.05), Vector3(cos(angle) * RADIUS, 0.26 + tall * 0.5, sin(angle) * RADIUS), glass,
				Vector3(0.12 * sin(angle), angle, 0.12 * cos(angle)))
		return
	kit.tube(RADIUS, RADIUS, HEIGHT - 0.42, Vector3(0, HEIGHT * 0.5, 0), glass, false, 18)
	kit.tube(RADIUS - 0.05, RADIUS - 0.05, HEIGHT - 0.60, Vector3(0, HEIGHT * 0.5 - 0.04, 0), fluid, false, 18)
	# Something curled up in it, head down, knees to its chest.
	var body: Material = Mats.specimen()
	kit.ball(0.22, Vector3(0, HEIGHT * 0.52, 0), body, Vector3(1.0, 1.15, 1.0))                  # head
	kit.ball(0.30, Vector3(0, HEIGHT * 0.33, 0.04), body, Vector3(1.0, 1.25, 0.85))              # body
	for side: float in [-1.0, 1.0]:
		kit.tube(0.07, 0.05, 0.42, Vector3(side * 0.22, HEIGHT * 0.36, -0.06), body, false, 8, Vector3(0.9, 0, side * 0.5))
		kit.tube(0.09, 0.06, 0.40, Vector3(side * 0.16, HEIGHT * 0.19, 0.10), body, false, 8, Vector3(-1.1, 0, side * 0.3))
	for i: int in 7:                                                                             # bubbles
		var lift: float = fmod(float(i) * 0.31, 1.0)
		kit.ball(0.03 + 0.02 * fmod(float(i) * 0.7, 1.0),
			Vector3(sin(float(i) * 2.1) * 0.3, 0.35 + lift * (HEIGHT - 0.9), cos(float(i) * 1.7) * 0.3), fluid)
