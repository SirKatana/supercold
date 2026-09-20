class_name DeepWater
extends Area3D
## A real body of water: a basin cut into the floor and filled. The player can fall in, swim,
## and climb out. A dude who ends up in it drowns. One of these per rectangular pool.

const T: Tuning = preload("res://data/tuning.tres")

## In cells.
var rect: Rect2i
var cell_size: float = 2.0
## World height of the surface, a little below the deck.
var surface_y: float = -0.14

var _splashed: Dictionary[int, bool] = {}


func _ready() -> void:
	add_to_group(&"deep_water")
	collision_layer = 0
	collision_mask = 2 | 4
	var size := Vector3(rect.size.x * cell_size, T.pool_depth, rect.size.y * cell_size)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, T.pool_depth + surface_y, size.z)
	shape.shape = box
	shape.position = Vector3(0, surface_y - box.size.y * 0.5, 0)
	add_child(shape)

	# The surface: finely divided so the shader can move it.
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	plane.subdivide_width = clampi(int(size.x * 2.0), 8, 96)
	plane.subdivide_depth = clampi(int(size.z * 2.0), 8, 96)
	plane.material = Mats.water_deep()
	surface.mesh = plane
	surface.position.y = surface_y
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)


func _splash(at: Vector3, big: bool) -> void:
	Shatter.burst(Game.entities_root(self), Vector3(at.x, surface_y + 0.05, at.z), 16 if big else 8, Mats.splash(),
		Vector3(0.3, 0.02, 0.3), Vector3.UP * (4.0 if big else 2.5), 0.07)
	Sfx.play(&"splash", at)


func _physics_process(_delta: float) -> void:
	var seen: Dictionary[int, bool] = {}
	for body: Node3D in get_overlapping_bodies():
		var id: int = body.get_instance_id()
		seen[id] = true
		if not _splashed.has(id):
			_splash(body.global_position, true)
		if body is Player:
			(body as Player).water_surface = surface_y
			(body as Player).in_water = 0.12
		elif body is PinkDude and (body as PinkDude).alive and body.global_position.y < surface_y - 0.5:
			(body as PinkDude).drown()
	_splashed = seen
