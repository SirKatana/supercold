class_name Mats
extends RefCounted
## Shared materials. White world, pink threats, black tools, cyan goals.

const PINK := Color("ff2d95")
const ACCENT := Color("7fe8ff")

static var _cache: Dictionary[StringName, StandardMaterial3D] = {}


static func _cached(key: StringName, build: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


static func wall() -> StandardMaterial3D:
	return _cached(&"wall", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.94, 0.95, 0.97)
		m.roughness = 1.0
		return m)


static func floor_mat() -> StandardMaterial3D:
	return _cached(&"floor", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.66, 0.68, 0.72)
		m.roughness = 0.9
		return m)


static func prop() -> StandardMaterial3D:
	return _cached(&"prop", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.74, 0.76, 0.80)
		m.roughness = 1.0
		return m)


static func black() -> StandardMaterial3D:
	return _cached(&"black", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.06)
		m.roughness = 0.6
		return m)


static func pink() -> StandardMaterial3D:
	return _cached(&"pink", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = PINK
		m.emission_enabled = true
		m.emission = PINK
		m.emission_energy_multiplier = 1.4
		m.roughness = 0.5
		return m)


static func pink_bright() -> StandardMaterial3D:
	return _cached(&"pink_bright", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.45, 0.75)
		m.emission_enabled = true
		m.emission = PINK
		m.emission_energy_multiplier = 3.0
		return m)


static func pink_trail() -> StandardMaterial3D:
	return _cached(&"pink_trail", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(PINK, 0.35)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func accent() -> StandardMaterial3D:
	return _cached(&"accent", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = ACCENT
		m.emission_enabled = true
		m.emission = ACCENT
		m.emission_energy_multiplier = 1.6
		return m)


static func locked() -> StandardMaterial3D:
	return _cached(&"locked", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.36, 0.40)
		m.roughness = 0.8
		return m)


static func glass() -> StandardMaterial3D:
	return _cached(&"glass", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.75, 0.92, 1.0, 0.28)
		m.roughness = 0.1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func door() -> StandardMaterial3D:
	return _cached(&"door", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.65, 0.70)
		m.roughness = 0.8
		return m)
