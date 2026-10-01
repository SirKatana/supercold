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
## What is inside, once it has been let out. Nothing until the release is thrown.
var opened: bool = false


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


## The release has been thrown: the glass goes, the fluid goes across the floor, and whatever
## was curled up in there walks out. Already-cracked tanks have nothing left to give.
func let_it_out() -> PinkDude:
	if cracked or opened:
		return null
	opened = true
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).mesh = MeshKit.cached(&"tank_cracked", _model.bind(true))
		elif child is OmniLight3D:
			(child as OmniLight3D).light_energy = 0.12
	Shatter.burst(Game.entities_root(self), global_position + Vector3(0, HEIGHT * 0.6, 0), 14,
		Mats.glass(), Vector3(0.3, 0.6, 0.3), Vector3.UP * 2.2, 0.13)
	Sfx.play(&"shatter", global_position)
	var spill := Puddle.new()
	spill.name = "TankFluid"
	spill.radius = 1.5
	spill.life = -1.0
	Game.entities_root(self).add_child(spill)
	spill.global_position = Vector3(global_position.x, 0.0, global_position.z)
	# What was in it. Down here they all wear the same skin as everything else.
	var out: PinkDude = Game.spawn_dude(global_position + Vector3(0, 0.05, 0), false, &"runner")
	if out != null:
		out.alerted = true
	return out


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
	# Something curled up in it, head down, knees to its chest, hands against the glass.
	var body: Material = Mats.specimen()
	var bone: Material = Mats.ceramic()
	var head_y: float = HEIGHT * 0.54
	kit.ball(0.20, Vector3(0, head_y, 0.02), body, Vector3(0.95, 1.15, 1.05))                    # skull
	kit.box(Vector3(0.20, 0.09, 0.14), Vector3(0, head_y - 0.15, -0.04), body, Vector3(0.35, 0, 0))   # jaw, hanging open
	for side: float in [-1.0, 1.0]:
		kit.ball(0.045, Vector3(side * 0.085, head_y + 0.02, -0.15), Mats.tank_fluid())          # an eye, milky
		kit.box(Vector3(0.016, 0.05, 0.05), Vector3(side * 0.16, head_y + 0.03, 0.03), body, Vector3(0, 0, 0.4 * side))   # ear frill
	# Spine and ribs: it is thin enough that you can count them.
	for i: int in 6:
		var y: float = HEIGHT * 0.45 - i * 0.075
		var span: float = 0.28 - absf(float(i) - 2.0) * 0.03
		kit.box(Vector3(0.07, 0.05, 0.09), Vector3(0, y, 0.10), bone)                            # vertebra
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(span, 0.028, 0.030), Vector3(side * span * 0.5, y, 0.02), bone, Vector3(0, 0, 0.18 * side))
	kit.box(Vector3(0.26, 0.34, 0.20), Vector3(0, HEIGHT * 0.33, 0.0), body)                     # chest
	kit.ball(0.17, Vector3(0, HEIGHT * 0.18, 0.02), body, Vector3(1.0, 0.9, 0.9))                # belly
	for side: float in [-1.0, 1.0]:
		# Arms: upper arm out, forearm forward, a hand flat on the glass with fingers spread.
		kit.tube(0.055, 0.042, 0.30, Vector3(side * 0.20, HEIGHT * 0.38, 0.02), body, false, 8, Vector3(0, 0, side * 1.0))
		kit.ball(0.05, Vector3(side * 0.30, HEIGHT * 0.31, 0.0), body)                           # elbow
		kit.tube(0.042, 0.032, 0.30, Vector3(side * 0.30, HEIGHT * 0.29, -0.16), body, false, 8, Vector3(1.25, 0, 0))
		kit.box(Vector3(0.10, 0.11, 0.03), Vector3(side * 0.30, HEIGHT * 0.28, -0.32), body)     # palm on the glass
		for finger: int in 4:
			kit.box(Vector3(0.018, 0.070, 0.022), Vector3(side * 0.30 + (finger - 1.5) * 0.026, HEIGHT * 0.34, -0.33), body)
		# Legs, folded up under it.
		kit.tube(0.070, 0.050, 0.26, Vector3(side * 0.13, HEIGHT * 0.15, 0.06), body, false, 8, Vector3(-1.0, 0, side * 0.35))
		kit.ball(0.055, Vector3(side * 0.17, HEIGHT * 0.20, -0.14), body)                        # knee
		kit.tube(0.050, 0.038, 0.24, Vector3(side * 0.16, HEIGHT * 0.12, -0.16), body, false, 8, Vector3(0.9, 0, 0))
		kit.box(Vector3(0.09, 0.05, 0.13), Vector3(side * 0.15, HEIGHT * 0.05, -0.12), body)     # foot
	for i: int in 7:                                                                             # bubbles
		var lift: float = fmod(float(i) * 0.31, 1.0)
		kit.ball(0.03 + 0.02 * fmod(float(i) * 0.7, 1.0),
			Vector3(sin(float(i) * 2.1) * 0.3, 0.35 + lift * (HEIGHT - 0.9), cos(float(i) * 1.7) * 0.3), fluid)
