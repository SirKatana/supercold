class_name Puddle
extends Area3D
## A wet or icy floor cell. A dude who crosses it at more than a walk goes down, slides,
## and loses his gun. The player is sure-footed.

const T: Tuning = preload("res://data/tuning.tres")

var icy: bool = false
## Above zero: a round spill of this radius instead of a floor cell.
var radius: float = 0.0
## Above zero: real seconds until it has dried up. It shrinks away over the last few.
var life: float = -1.0

var _mesh: MeshInstance3D
var _age: float = 0.0
const DRY_OFF: float = 6.0


func _ready() -> void:
	add_to_group(&"puddles")
	collision_layer = 0
	collision_mask = 4
	var shape := CollisionShape3D.new()
	_mesh = MeshInstance3D.new()
	if radius > 0.0:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = 1.0
		shape.shape = cylinder
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.012
		disc.radial_segments = 28
		disc.material = Mats.water()
		_mesh.mesh = disc
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(T.cell_size, 1.0, T.cell_size)
		shape.shape = box
		var mesh := BoxMesh.new()
		# Full cell, so neighbouring wet cells join into one sheet with no grid showing.
		mesh.size = Vector3(T.cell_size, 0.012, T.cell_size)
		mesh.material = Mats.ice_floor() if icy else Mats.water()
		_mesh.mesh = mesh
	shape.position.y = 0.5
	add_child(shape)
	_mesh.position.y = 0.008
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## A spill dries on the player's clock, not the world's: a minute and a half is a minute and a half.
func _process(delta: float) -> void:
	if life <= 0.0:
		return
	_age += delta
	if _age >= life:
		queue_free()
	elif _age > life - DRY_OFF:
		var left: float = (life - _age) / DRY_OFF
		_mesh.scale = Vector3(left, 1.0, left)
		(get_child(0) as CollisionShape3D).scale = Vector3(left, 1.0, left)


func seconds_left() -> float:
	return maxf(0.0, life - _age) if life > 0.0 else INF


func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		var dude: PinkDude = body as PinkDude
		if dude == null or not dude.alive:
			continue
		var speed: float = dude.desired_velocity.length()
		if speed >= (T.slip_speed * 0.6 if icy else T.slip_speed):
			dude.slip(dude.desired_velocity)
