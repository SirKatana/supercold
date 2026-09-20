class_name FreezeBlast
extends Node3D
## The flash of cold from a freeze bomb: a pale sphere and a frost ring racing outward, ice
## shards in the air, and everyone in reach frozen. On world time.

const T: Tuning = preload("res://data/tuning.tres")

var _age: float = 0.0
var _sphere: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D


## Freezes every dude in the radius with a clear line to the bomb. Returns how many.
static func go(parent: Node, at: Vector3) -> int:
	var blast := FreezeBlast.new()
	parent.add_child(blast)
	blast.global_position = at
	blast._build()
	Sfx.play(&"freeze", at)
	TimeManager.burst(0.2, 0.4)
	var count: int = 0
	var space: PhysicsDirectSpaceState3D = blast.get_world_3d().direct_space_state
	for node: Node in blast.get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude == null or not dude.alive:
			continue
		var chest: Vector3 = dude.global_position + Vector3.UP * 1.1
		if chest.distance_to(at) > T.freeze_radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, chest, 1)
		if space.intersect_ray(query).is_empty():
			dude.freeze(T.freeze_seconds)
			if dude.frozen:
				count += 1
	return count


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build() -> void:
	_sphere = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 16
	ball.rings = 8
	_sphere.mesh = ball
	_sphere.material_override = _material(Color(0.75, 0.93, 1.0, 0.6))
	add_child(_sphere)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	_ring.mesh = torus
	_ring.material_override = _material(Color(0.9, 0.98, 1.0, 0.8))
	add_child(_ring)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.85, 1.0)
	_light.light_energy = 6.0
	_light.omni_range = T.freeze_radius * 2.0
	_light.shadow_enabled = false
	add_child(_light)
	Shatter.burst(get_parent(), global_position, 28, Mats.ice(), Vector3.ONE * 0.4, Vector3.UP * 2.5, 0.11)


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	_age += wd
	var t: float = clampf(_age / 0.6, 0.0, 1.0)
	var reach: float = lerpf(0.2, T.freeze_radius, 1.0 - pow(1.0 - t, 3.0))
	_sphere.scale = Vector3.ONE * reach
	(_sphere.material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - t)
	_ring.scale = Vector3(reach, 0.3, reach)
	_ring.position.y = 0.1 - global_position.y
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - t)
	_light.light_energy = 6.0 * (1.0 - t)
	if _age > 0.7:
		queue_free()
