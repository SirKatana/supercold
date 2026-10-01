class_name FallingPot
extends Node3D
## A pot plant off the top of a bookcase. It falls, it breaks where it lands, and the soil and
## the shards take the legs from under anybody standing there. It never kills: the whole point
## of it is a dude hobbling out of the wreckage.

const T: Tuning = preload("res://data/tuning.tres")

var velocity: Vector3 = Vector3.ZERO
var _spin: Vector3 = Vector3.ZERO
var _body: Node3D
var _broken: bool = false


func _ready() -> void:
	add_to_group(&"falling_pots")
	_body = Node3D.new()
	add_child(_body)
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshKit.cached(&"pot_plant", _model)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mesh)
	_spin = Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-5, 5))


func _physics_process(delta: float) -> void:
	if _broken:
		return
	var wd: float = TimeManager.world_delta(delta)
	if wd <= 0.0:
		return
	velocity.y -= T.throw_gravity * Game.gravity_scale * wd
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * wd
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 32)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_body.rotation += _spin * wd
		return
	global_position = hit["position"]
	_break()


## Earthenware all over the floor, and anybody close enough goes down on one knee.
func _break() -> void:
	_broken = true
	var root: Node3D = Game.entities_root(self)
	Shatter.burst(root, global_position + Vector3(0, 0.1, 0), 10, Mats.ceramic(),
		Vector3(0.05, 0.035, 0.05), Vector3.UP * 2.2, 0.16)
	Shatter.burst(root, global_position + Vector3(0, 0.08, 0), 8, Mats.soil(),
		Vector3(0.05, 0.04, 0.05), Vector3.UP * 1.4, 0.12)
	Shatter.burst(root, global_position + Vector3(0, 0.16, 0), 5, Mats.leaf_green(),
		Vector3(0.09, 0.02, 0.05), Vector3.UP * 1.8, 0.2)
	Sfx.play(&"shatter", global_position)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude == null or not dude.alive:
			continue
		# Flat distance: a pot that lands at his feet is still a pot that landed on him, and
		# his origin is on the floor while the pot breaks at whatever height it met something.
		var flat := Vector2(dude.global_position.x - global_position.x,
			dude.global_position.z - global_position.z)
		if flat.length() <= T.pot_hurt_radius:
			dude.break_a_leg()
	queue_free()


## A terracotta pot, soil, and something green in it.
static func _model(kit: MeshKit) -> void:
	var clay: Material = Mats.terracotta()
	var soil: Material = Mats.soil()
	var leaf: Material = Mats.leaf_green()
	kit.tube(0.115, 0.085, 0.20, Vector3(0, 0.0, 0), clay, false, 12)
	kit.tube(0.125, 0.125, 0.03, Vector3(0, 0.10, 0), clay, false, 12)       # rim
	kit.tube(0.100, 0.100, 0.02, Vector3(0, 0.085, 0), soil, false, 12)
	for i: int in 7:
		var about: float = TAU * i / 7.0
		var lean: float = 0.5 + randf() * 0.4
		kit.box(Vector3(0.05, 0.015, 0.16), Vector3(cos(about) * 0.07, 0.17, sin(about) * 0.07),
			leaf, Vector3(sin(about) * lean, -about, cos(about) * lean))
