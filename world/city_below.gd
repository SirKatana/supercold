class_name CityBelow
extends Node3D
## What is out of the window: the rest of the city, a long way down. Blocks of towers with lit
## windows in them, thinning out into haze toward the horizon.
##
## Decoration only, with no collision anywhere. It is built once per floor that has windows and
## sits well below the deck, so it is only ever seen through a hole in the outer wall.

const T: Tuning = preload("res://data/tuning.tres")

## The band the rooftops sit in, relative to this floor: some of the city is above you and
## most of it below, which is what makes the building feel high up rather than on a plinth.
const ROOF_HIGH: float = 26.0
const ROOF_LOW: float = -34.0
const DROP: float = 9.0
const REACH: float = 190.0

## The middle of the building, so the towers can be kept clear of it.
var around: Vector3 = Vector3.ZERO
var footprint: float = 30.0


func _ready() -> void:
	add_to_group(&"city")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(around.x * 31.0 + around.z * 17.0) + 99
	_ground(rng)
	_towers(rng)


## The street plan, far enough down that it reads as ground rather than as a floor.
func _ground(_rng: RandomNumberGenerator) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(REACH * 2.4, 2.0, REACH * 2.4)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.city_ground()
	mi.position = around + Vector3(0, -DROP - 62.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Towers in a loose grid, each one a slab with a lit window pattern on it. They are merged per
## material by MeshKit, so the whole skyline is a handful of draw calls.
func _towers(rng: RandomNumberGenerator) -> void:
	var kit := MeshKit.new()
	var concrete: Material = Mats.city_concrete()
	var glass: Material = Mats.city_glass()
	var lit: Material = Mats.city_lit()
	var placed: int = 0
	for ring: int in 7:
		var radius: float = footprint + 16.0 + ring * 24.0
		var count: int = 6 + ring * 4
		for i: int in count:
			var about: float = TAU * i / count + rng.randf() * 0.4
			var out: float = radius * (0.82 + rng.randf() * 0.36)
			if out > REACH:
				continue
			var at := Vector3(around.x + cos(about) * out, 0.0, around.z + sin(about) * out)
			# Nothing directly under the building itself.
			if absf(at.x - around.x) < footprint * 0.7 and absf(at.z - around.z) < footprint * 0.7:
				continue
			var wide: float = 6.0 + rng.randf() * 9.0
			var deep: float = 6.0 + rng.randf() * 9.0
			var tall: float = 26.0 + rng.randf() * 60.0 - ring * 2.0
			var roof: float = ROOF_HIGH - rng.randf() * (ROOF_HIGH - ROOF_LOW) * (0.35 + ring * 0.12)
			var base: float = roof - tall
			kit.box(Vector3(wide, tall, deep), Vector3(at.x, (roof + base) * 0.5, at.z), concrete)
			# A glazed face on the two sides most likely to be seen, with a few lights on.
			for face: int in 2:
				var side: float = 1.0 if face == 0 else -1.0
				kit.box(Vector3(wide * 0.82, tall * 0.9, 0.3),
					Vector3(at.x, (roof + base) * 0.5, at.z + side * deep * 0.5), glass)
			var storeys: int = int(tall / 3.4)
			for storey: int in storeys:
				if rng.randf() > 0.42:
					continue
				var y: float = base + 2.0 + storey * 3.4
				var across: float = (rng.randf() - 0.5) * wide * 0.6
				kit.box(Vector3(1.5, 1.1, 0.34), Vector3(at.x + across, y, at.z + deep * 0.5), lit)
			# A light on the roof of the taller ones, as aircraft warning.
			if roof > 2.0:
				kit.box(Vector3(0.7, 0.7, 0.7), Vector3(at.x, roof + 0.6, at.z), Mats.city_beacon())
			placed += 1
	var mi := MeshInstance3D.new()
	mi.mesh = kit.bake()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
