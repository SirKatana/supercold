class_name Explosion
extends Node3D
## A gas barrel going up. Everything here runs on world time, so if you stand still you
## watch the fireball unfold in slow motion.
##
## Layers of the effect: a white-hot flash, a fireball that swells and rolls upward, a ring
## of flame tongues thrown outward, a fast ground shockwave, black smoke that rises and
## thins, a light that flares and dies, flying debris, and a scorch mark that stays.

const T: Tuning = preload("res://data/tuning.tres")

var _age: float = 0.0
var _life: float = 3.4
var _radius: float = 5.5

var _flash: MeshInstance3D
var _core: MeshInstance3D
var _wave: MeshInstance3D
var _light: OmniLight3D
## [node, velocity, birth, life, start size, end size, kind] where kind 0 is fire and 1 is smoke
var _puffs: Array = []


## Spawns the effect and deals the damage. Returns how many dudes it killed.
static func detonate(parent: Node, at: Vector3, source: Node = null) -> int:
	var boom := Explosion.new()
	parent.add_child(boom)
	boom.global_position = at
	boom._radius = T.barrel_radius
	boom._build()
	Sfx.play(&"explosion", at)
	TimeManager.burst(0.25, 0.5)
	Game.emit_noise(at, T.dude_hearing * 2.5)
	return boom._blast(source)


func _sphere(material: Material, segments: int = 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.emission_enabled = energy > 0.0
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _build() -> void:
	_flash = _sphere(_glow(Color(1.0, 0.98, 0.85, 1.0), 6.0))
	_core = _sphere(_glow(Color(1.0, 0.62, 0.12, 0.95), 3.5))

	_wave = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.86
	ring.outer_radius = 1.0
	ring.rings = 28
	ring.ring_segments = 6
	_wave.mesh = ring
	_wave.material_override = _glow(Color(1.0, 0.85, 0.6, 0.7), 1.5)
	_wave.position.y = 0.12 - global_position.y * 0.0
	_wave.scale = Vector3(0.1, 0.25, 0.1)
	add_child(_wave)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25)
	_light.light_energy = 9.0
	_light.omni_range = _radius * 2.2
	_light.shadow_enabled = false
	_light.position.y = 0.8
	add_child(_light)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Flame tongues thrown outward and up.
	for i: int in 16:
		var angle: float = TAU * i / 16.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(angle), rng.randf_range(0.25, 1.1), sin(angle)).normalized()
		var node: MeshInstance3D = _sphere(_glow(Color(1.0, 0.45, 0.08, 0.9), 2.6), 8)
		_puffs.append([node, out * rng.randf_range(3.0, 6.5), 0.0, rng.randf_range(0.5, 0.9), 0.25, rng.randf_range(0.7, 1.2), 0])
	# The rolling fireball: big slow blobs that climb and burn for over a second.
	for i: int in 9:
		var drift := Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(1.0, 2.4), rng.randf_range(-1.1, 1.1))
		var node: MeshInstance3D = _sphere(_glow(Color(1.0, 0.55, 0.10, 0.85), 2.2), 10)
		_puffs.append([node, drift, rng.randf_range(0.0, 0.25), rng.randf_range(1.0, 1.6), 0.45, rng.randf_range(1.0, 1.6), 0])
	# Smoke: many separate grey puffs born over most of a second, drifting apart as they rise.
	for i: int in 18:
		var drift := Vector3(rng.randf_range(-1.7, 1.7), rng.randf_range(1.0, 2.6), rng.randf_range(-1.7, 1.7))
		var shade: float = rng.randf_range(0.10, 0.26)
		var node: MeshInstance3D = _sphere(_glow(Color(shade, shade * 0.95, shade * 0.92, 0.0), 0.0), 10)
		_puffs.append([node, drift, rng.randf_range(0.12, 0.95), rng.randf_range(1.6, 2.3), 0.35, rng.randf_range(0.9, 1.5), 1])
	for puff: Array in _puffs:
		(puff[0] as MeshInstance3D).position = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.2, 0.9), rng.randf_range(-0.3, 0.3))
		(puff[0] as MeshInstance3D).scale = Vector3.ONE * 0.01

	# What is left on the floor afterwards.
	var mark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = _radius * 0.42
	disc.bottom_radius = _radius * 0.42
	disc.height = 0.012
	disc.radial_segments = 20
	mark.mesh = disc
	mark.material_override = Mats.scorch()
	mark.top_level = true
	get_parent().add_child(mark)
	mark.global_position = Vector3(global_position.x, 0.012, global_position.z)

	Shatter.burst(get_parent(), global_position + Vector3.UP * 0.5, 26, Mats.barrel_red(), Vector3(0.3, 0.45, 0.3), Vector3.UP * 3.5, 0.2)
	Shatter.burst(get_parent(), global_position + Vector3.UP * 0.5, 14, Mats.rubber(), Vector3(0.3, 0.3, 0.3), Vector3.UP * 5.0, 0.12)
	# Embers: small glowing bits thrown high that fall back burning.
	Shatter.burst(get_parent(), global_position + Vector3.UP * 0.6, 30, _glow(Color(1.0, 0.55, 0.12, 1.0), 3.0), Vector3(0.4, 0.4, 0.4), Vector3.UP * 6.5, 0.05)


## True if nothing solid stands between the blast and the point. Walls are cover.
func _reaches(point: Vector3) -> bool:
	var from: Vector3 = global_position + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, point, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _blast(source: Node) -> int:
	var here: Vector3 = global_position
	var killed: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude == null or not dude.alive:
			continue
		var chest: Vector3 = dude.global_position + Vector3.UP * 1.1
		if chest.distance_to(here) <= _radius and _reaches(chest):
			dude.on_explosion(here)
			if not dude.alive:
				killed += 1
	for node: Node in get_tree().get_nodes_in_group(&"cleaners"):
		var bystander: Node3D = node as Node3D
		if bystander.global_position.distance_to(here) <= _radius and _reaches(bystander.global_position + Vector3.UP * 1.1):
			bystander.call(&"on_explosion", here)
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.alive:
		var d: float = player.chest_position().distance_to(here)
		if d <= _radius * 2.2:
			player.fx.shake(0.07 * clampf(1.0 - d / (_radius * 2.2), 0.15, 1.0))
		if d <= T.barrel_player_radius and _reaches(player.chest_position()):
			player.hit_from(player.chest_position() - here, "A GAS BARREL")
	for group: StringName in [&"doors", &"see_through"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body: Node3D = node as Node3D
			if body != null and body.global_position.distance_to(here) <= _radius and body.has_method(&"take_damage"):
				if body is Door:
					(body as Door).smash(body.global_position - here)
				else:
					body.call(&"take_damage", 99, body.global_position - here)
	# Other barrels in reach cook off a beat later, one after another.
	for node: Node in get_tree().get_nodes_in_group(&"barrels"):
		var other: GasBarrel = node as GasBarrel
		if other != null and other != source and not other.exploded and other.global_position.distance_to(here) <= _radius:
			other.cook_off(T.barrel_chain_delay * (1.0 + other.global_position.distance_to(here) * 0.35))
	return killed


func _physics_process(delta: float) -> void:
	var wd: float = TimeManager.world_delta(delta)
	if wd <= 0.0:
		return
	_age += wd
	if _age >= _life:
		queue_free()
		return

	var flash_t: float = clampf(_age / 0.12, 0.0, 1.0)
	_flash.scale = Vector3.ONE * lerpf(0.4, _radius * 0.5, flash_t)
	(_flash.material_override as StandardMaterial3D).albedo_color.a = 1.0 - flash_t
	_flash.visible = flash_t < 1.0

	var core_t: float = clampf(_age / 0.55, 0.0, 1.0)
	var swell: float = 1.0 - pow(1.0 - core_t, 3.0)
	_core.scale = Vector3.ONE * lerpf(0.3, _radius * 0.36, swell)
	_core.position.y = 0.6 + swell * 0.9
	var core_material: StandardMaterial3D = _core.material_override
	core_material.albedo_color = Color(1.0, 0.62, 0.12).lerp(Color(0.5, 0.12, 0.02), core_t)
	core_material.albedo_color.a = 0.95 * (1.0 - core_t * core_t)
	core_material.emission = core_material.albedo_color
	_core.visible = core_t < 1.0

	var wave_t: float = clampf(_age / 0.4, 0.0, 1.0)
	var reach: float = lerpf(0.2, _radius, 1.0 - pow(1.0 - wave_t, 2.0))
	_wave.scale = Vector3(reach, 0.35, reach)
	(_wave.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - wave_t)
	_wave.visible = wave_t < 1.0

	_light.light_energy = 9.0 * maxf(0.0, 1.0 - _age / 0.7)

	for puff: Array in _puffs:
		var node: MeshInstance3D = puff[0]
		var t: float = (_age - float(puff[2])) / float(puff[3])
		if t < 0.0:
			continue
		if t >= 1.0:
			node.visible = false
			continue
		var velocity: Vector3 = puff[1]
		# Thrown hard, then slowed by the air, then lifted by its own heat.
		velocity = velocity * (1.0 - t * 0.75) + Vector3.UP * t * 1.2
		node.position += velocity * wd
		node.scale = Vector3.ONE * lerpf(puff[4], puff[5], 1.0 - pow(1.0 - t, 2.0))
		var material: StandardMaterial3D = node.material_override
		if puff[6] == 0:
			material.albedo_color = Color(1.0, 0.78, 0.25).lerp(Color(0.35, 0.06, 0.02), t)
			material.albedo_color.a = 0.9 * (1.0 - t * t)
			material.emission = material.albedo_color
			material.emission_energy_multiplier = 2.6 * (1.0 - t)
		else:
			material.albedo_color.a = 0.40 * sin(PI * clampf(t, 0.0, 1.0)) * (1.0 - t * 0.3)
