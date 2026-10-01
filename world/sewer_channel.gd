class_name SewerChannel
extends Area3D
## The main channel of a sewer: a half-pipe sunk into the floor, running the length of a
## corridor, with green water in the bottom of it and bodies going slowly past.
##
## It is a trough, not a puddle. The sides are real collision built out of a fan of slabs, so
## you can slide down into it, wade along the bottom and climb out the other side. Dudes will
## not path across it, because the floor slabs are cut away over a channel exactly as they are
## over a pool.

const T: Tuning = preload("res://data/tuning.tres")

## How deep the middle of the pipe sits below the deck, and how deep the water in it is.
const DEPTH: float = 1.30
const WATER: float = 0.52
## How many slabs make up each side of the U.
const SEGMENTS: int = 6

## In cells. The long axis is whichever side is longer.
var rect: Rect2i
var cell_size: float = 2.0

var _along_x: bool = true
var _length: float = 0.0
var _width: float = 0.0
var _surface_y: float = 0.0
var _bodies: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"sewer_channel")
	collision_layer = 0
	collision_mask = 2 | 4
	_width = rect.size.x * cell_size
	_length = rect.size.y * cell_size
	_along_x = rect.size.x >= rect.size.y
	if _along_x:
		_width = rect.size.y * cell_size
		_length = rect.size.x * cell_size
	_surface_y = -DEPTH + WATER

	_build_trough()
	_build_water()
	_float_the_dead()

	# The water itself: being in it is being in the muck.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_width if not _along_x else _length, WATER, _length if not _along_x else _width)
	if _along_x:
		box.size = Vector3(_length, WATER, _width)
	else:
		box.size = Vector3(_width, WATER, _length)
	shape.shape = box
	shape.position.y = -DEPTH + WATER * 0.5
	add_child(shape)


## The half-pipe. Each side is a fan of long slabs, each tilted a little more than the last, so
## the cross-section is a U that can be walked down and climbed out of.
func _build_trough() -> void:
	var brick: Material = Mats.sewer_brick()
	var body := StaticBody3D.new()
	body.name = "Trough"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var half: float = _width * 0.5
	for side: float in [-1.0, 1.0]:
		for i: int in SEGMENTS:
			# Angle sweeps from flat at the bottom to steep at the lip.
			var a0: float = PI * 0.5 * i / SEGMENTS
			var a1: float = PI * 0.5 * (i + 1) / SEGMENTS
			var mid: float = (a0 + a1) * 0.5
			var across: float = side * sin(mid) * half
			var down: float = -DEPTH + (1.0 - cos(mid)) * DEPTH
			var span: float = half * (sin(a1) - sin(a0)) / maxf(cos(mid), 0.25)
			_slab(body, span, mid * side, across, down, brick)
	# The invert: a flat strip along the very bottom, so there is somewhere to stand.
	_slab(body, _width * 0.22, 0.0, 0.0, -DEPTH, Mats.sewer_slime())


func _slab(body: StaticBody3D, span: float, tilt: float, across: float, down: float, material: Material) -> void:
	var size := Vector3(_length, 0.22, maxf(span, 0.12))
	var at := Vector3(0, down, across)
	var turn := Vector3(tilt, 0, 0)
	if not _along_x:
		size = Vector3(maxf(span, 0.12), 0.22, _length)
		at = Vector3(across, down, 0)
		turn = Vector3(0, 0, -tilt)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	mi.rotation = turn
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	shape.rotation = turn
	body.add_child(shape)


func _build_water() -> void:
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var span: float = _width * 0.82
	plane.size = Vector2(_length, span) if _along_x else Vector2(span, _length)
	plane.subdivide_width = clampi(int(plane.size.x * 2.0), 8, 80)
	plane.subdivide_depth = clampi(int(plane.size.y * 2.0), 8, 80)
	plane.material = Mats.water_sewer()
	surface.mesh = plane
	surface.position.y = _surface_y
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)


## What is in the water. They went in some time ago.
func _float_the_dead() -> void:
	var how_many: int = clampi(int(_length / 7.0), 1, 5)
	for i: int in how_many:
		var drifter := SewerBody.new()
		drifter.along_x = _along_x
		drifter.run_length = _length
		drifter.surface_y = _surface_y
		drifter.offset = _length * (float(i) + 0.35) / float(how_many) - _length * 0.5
		drifter.sideways = (randf() - 0.5) * _width * 0.3
		add_child(drifter)
		_bodies.append(drifter)
