class_name Chandelier
extends Node3D
## A chandelier hanging from the ceiling. It swings like a pendulum, and it jingles when a body
## is flung into it, when a round goes through it, or when a blast shakes the room. Purely
## decorative: nothing collides with it, so it can never trap a player or block a shot.

const T: Tuning = preload("res://data/tuning.tres")
const SWING_DAMP: float = 1.4
const PERIOD: float = 2.1

var _swing: Vector2 = Vector2.ZERO          # radians, x forward and y sideways
var _speed: Vector2 = Vector2.ZERO
var _ring: float = 0.0
var _lamp: OmniLight3D
var _quiet_for: float = 0.0


static func hang(parent: Node, at: Vector3, big: bool = false) -> Chandelier:
	var c := Chandelier.new()
	c.name = "Chandelier"
	parent.add_child(c)
	# A level is built before it is put in the tree, so this is a local position on purpose.
	c.position = Vector3(at.x, T.wall_height, at.z)
	c.scale = Vector3.ONE * (1.25 if big else 1.0)
	c.rotation.y = randf() * TAU
	return c


func _ready() -> void:
	add_to_group(&"hanging")
	add_to_group(&"time_scaled")
	var frame := MeshInstance3D.new()
	frame.mesh = MeshKit.cached(&"chandelier", _model)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frame)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, -0.75, 0)
	_lamp.omni_range = 5.0
	_lamp.light_energy = 0.35
	_lamp.light_color = Color(1.0, 0.92, 0.75)
	_lamp.shadow_enabled = false
	add_child(_lamp)


## Chain, tiers of arms with candles, and two rings of crystal drops. Origin at the ceiling.
static func _model(kit: MeshKit) -> void:
	var brass: Material = Mats.brass()
	var crystal: Material = Mats.glass()
	var wax: Material = Mats.ceramic()
	var flame: Material = Mats.accent()
	for i: int in 5:
		kit.tube(0.013, 0.013, 0.09, Vector3(0, -0.05 - i * 0.09, 0), brass, false, 6)       # chain
	kit.tube(0.05, 0.10, 0.10, Vector3(0, -0.56, 0), brass, false, 10)                        # canopy
	kit.tube(0.035, 0.035, 0.30, Vector3(0, -0.72, 0), brass, false, 8)                        # stem
	kit.ball(0.09, Vector3(0, -0.90, 0), brass)                                                # body
	for tier: int in 2:
		var radius: float = 0.46 - tier * 0.16
		var y: float = -0.80 - tier * 0.18
		var arms: int = 8 if tier == 0 else 5
		kit.tube(radius, radius, 0.018, Vector3(0, y - 0.02, 0), brass, false, 18)             # ring
		for a: int in arms:
			var angle: float = TAU * a / arms + tier * 0.4
			var out := Vector3(cos(angle), 0, sin(angle))
			kit.box(Vector3(radius, 0.016, 0.016), out * radius * 0.5 + Vector3(0, y, 0), brass, Vector3(0, -angle, 0))
			kit.tube(0.028, 0.032, 0.05, out * radius + Vector3(0, y + 0.03, 0), brass, false, 8)   # cup
			kit.tube(0.020, 0.022, 0.11, out * radius + Vector3(0, y + 0.10, 0), wax, false, 8)     # candle
			kit.ball(0.022, out * radius + Vector3(0, y + 0.18, 0), flame, Vector3(0.7, 1.5, 0.7))  # flame
			# Crystal drops under each arm, on short strings.
			for d: int in 3:
				var drop: Vector3 = out * (radius - 0.05 - d * 0.03) + Vector3(0, y - 0.07 - d * 0.05, 0)
				kit.box(Vector3(0.022, 0.05, 0.022), drop, crystal, Vector3(0, angle, 0.5))
	kit.box(Vector3(0.05, 0.10, 0.05), Vector3(0, -1.22, 0), crystal, Vector3(0, 0.4, 0.4))     # the finial drop


## Something hit it. `push` is the direction it was hit from, in world space.
func knock(push: Vector3) -> void:
	var flat := Vector2(push.x, push.z)
	if flat.length() > 0.01:
		_speed += flat.normalized() * minf(2.4, 0.9 + flat.length())
	_ring = 1.0
	if _quiet_for <= 0.0:
		_quiet_for = 0.25      # one jingle per knock, not one per joint that touched it
		Sfx.play(&"jingle", global_position)


func _process(delta: float) -> void:
	_quiet_for = maxf(0.0, _quiet_for - delta)
	var wd: float = TimeManager.world_delta(delta)
	if wd <= 0.0:
		return
	# A pendulum: pulled back toward straight down, and slowly losing its swing.
	var pull: float = pow(TAU / PERIOD, 2.0)
	_speed -= _swing * pull * wd
	_speed *= maxf(0.0, 1.0 - SWING_DAMP * wd)
	_swing += _speed * wd
	_swing = _swing.limit_length(0.5)
	rotation.x = _swing.x
	rotation.z = -_swing.y
	_ring = maxf(0.0, _ring - wd * 1.2)
	_lamp.light_energy = 0.35 + 0.5 * _ring * absf(sin(Time.get_ticks_msec() * 0.02))


## A round through the crystals, or a blast that shakes the room.
func on_bullet_hit(_bullet: Node, point: Vector3, _normal: Vector3) -> bool:
	knock(global_position - point)
	return false
