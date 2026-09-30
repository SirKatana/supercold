class_name Planetoid
extends StaticBody3D
## A little rock hanging over an open station floor, for the orbiters to stand on. Solid world
## collision, so it stops a bullet and gives whoever is up there something to duck behind.
##
## It turns slowly on world time, like everything else out there.

const T: Tuning = preload("res://data/tuning.tres")

var radius: float = 2.0
## How fast it turns, radians of world time.
var spin: float = 0.12
## Every third one wears a ring.
var ringed: bool = false

var _ball: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)

	_ball = Node3D.new()
	add_child(_ball)
	var mesh := MeshInstance3D.new()
	var key := StringName("planetoid_%d%s" % [int(radius * 10.0), "_ring" if ringed else ""])
	var r: float = radius
	var with_ring: bool = ringed
	mesh.mesh = MeshKit.cached(key, func(kit: MeshKit) -> void: _model(kit, r, with_ring))
	_ball.add_child(mesh)


func _process(delta: float) -> void:
	_ball.rotation.y = wrapf(_ball.rotation.y + TimeManager.world_delta(delta) * spin, 0.0, TAU)
	_ball.rotation.x = wrapf(_ball.rotation.x + TimeManager.world_delta(delta) * spin * 0.3, 0.0, TAU)


## A pitted rock: the body, a few craters sunk into it, some boulders on top, and a ring of
## small stones for the ones that have one.
static func _model(kit: MeshKit, r: float, with_ring: bool) -> void:
	var rock: Material = Mats.stone()
	var dark: Material = Mats.gunmetal()
	var dust: Material = Mats.prop()
	kit.ball(r, Vector3.ZERO, rock, Vector3(1.0, 0.92, 1.05))
	# Craters: darker discs pressed a little way into the surface.
	for pit: int in 7:
		var about: float = TAU * pit / 7.0 + float(pit) * 0.7
		var up: float = sin(float(pit) * 1.7) * 0.8
		var out := Vector3(cos(about) * sqrt(maxf(1.0 - up * up, 0.0)), up,
			sin(about) * sqrt(maxf(1.0 - up * up, 0.0)))
		var size: float = r * (0.16 + float(pit % 3) * 0.07)
		kit.ball(size, out * (r * 0.94), dark, Vector3(1.0, 0.35, 1.0))
	# Boulders round the crown, so the silhouette is not a clean ball.
	for lump: int in 5:
		var about: float = TAU * lump / 5.0 + 0.4
		kit.ball(r * 0.15, Vector3(cos(about) * r * 0.55, r * 0.88, sin(about) * r * 0.55), dust)
	if not with_ring:
		return
	for stone: int in 34:
		var about: float = TAU * stone / 34.0
		var band: float = r * (1.55 + float(stone % 3) * 0.18)
		kit.box(Vector3(r * 0.16, r * 0.035, r * 0.10),
			Vector3(cos(about) * band, sin(about * 3.0) * r * 0.05, sin(about) * band), dust,
			Vector3(0.12, -about, 0.0))
