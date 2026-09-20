class_name Puddle
extends Area3D
## A wet or icy floor cell. A dude who crosses it at more than a walk goes down, slides,
## and loses his gun. The player is sure-footed.

const T: Tuning = preload("res://data/tuning.tres")

var icy: bool = false


func _ready() -> void:
	add_to_group(&"puddles")
	collision_layer = 0
	collision_mask = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(T.cell_size, 1.0, T.cell_size)
	shape.shape = box
	shape.position.y = 0.5
	add_child(shape)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	# Full cell, so neighbouring wet cells join into one sheet with no grid showing.
	mesh.size = Vector3(T.cell_size, 0.012, T.cell_size)
	mesh.material = Mats.ice_floor() if icy else Mats.water()
	mi.mesh = mesh
	mi.position.y = 0.008
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		var dude: PinkDude = body as PinkDude
		if dude == null or not dude.alive:
			continue
		var speed: float = dude.desired_velocity.length()
		if speed >= (T.slip_speed * 0.6 if icy else T.slip_speed):
			dude.slip(dude.desired_velocity)
