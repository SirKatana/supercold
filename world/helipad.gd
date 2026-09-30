class_name Helipad
extends Node3D
## The roof exit: a landing pad that lights up cold cyan once the floor is clear.
## Floors inside the building use Elevator instead.

signal entered

const T: Tuning = preload("res://data/tuning.tres")

var unlocked: bool = false

var helicopter: Helicopter = null

var _pad: MeshInstance3D
var _beam: MeshInstance3D
var _area: Area3D


func _ready() -> void:
	add_to_group(&"exit")
	_pad = MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(T.cell_size * 0.9, 0.06, T.cell_size * 0.9)
	_pad.mesh = pad_mesh
	_pad.position.y = 0.03
	add_child(_pad)

	_beam = MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.12, T.wall_height, 0.12)
	_beam.mesh = beam_mesh
	_beam.position.y = T.wall_height * 0.5
	add_child(_beam)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(T.cell_size * 0.8, 2.0, T.cell_size * 0.8)
	shape.shape = box
	shape.position.y = 1.0
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)

	Game.floor_cleared.connect(unlock)
	_apply_look()
	if Game.is_floor_clear() and Game.state == Game.State.CLEARED:
		unlock()


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	_apply_look()
	Sfx.play(&"ding", global_position)
	_call_the_helicopter()
	# The player may already be standing on the pad.
	for body: Node3D in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _apply_look() -> void:
	var material: Material = Mats.accent() if unlocked else Mats.locked()
	(_pad.mesh as BoxMesh).material = material
	(_beam.mesh as BoxMesh).material = material
	_beam.visible = unlocked


## The roof exit is not a lift: a helicopter comes in and takes him off the building.
func _call_the_helicopter() -> void:
	if helicopter != null and is_instance_valid(helicopter):
		return
	helicopter = Helicopter.new()
	Game.entities_root(self).add_child(helicopter)
	helicopter.fly_in(global_position)
	helicopter.landed.connect(_on_helicopter_landed)


## It may have landed while he was already standing on the pad.
func _on_helicopter_landed() -> void:
	for body: Node3D in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	if not unlocked or not (body is Player) or not (body as Player).alive:
		return
	if helicopter != null and is_instance_valid(helicopter):
		if not helicopter.has_landed:
			return      # it is still on its way in
		entered.emit()
		helicopter.board(body as Player)
		return
	entered.emit()
	Game.next_floor.call_deferred()
