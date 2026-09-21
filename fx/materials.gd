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


static func gunmetal() -> StandardMaterial3D:
	return _cached(&"gunmetal", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.42, 0.46, 0.53)
		m.metallic = 0.35
		m.roughness = 0.38
		return m)


static func _plain(key: StringName, colour: Color, roughness: float = 0.8, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	return _cached(key, func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = roughness
		m.metallic = metallic
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = colour
			m.emission_energy_multiplier = glow
		return m)


static func paper() -> StandardMaterial3D:
	return _plain(&"paper", Color(0.97, 0.97, 0.95), 1.0)


static func ceramic() -> StandardMaterial3D:
	return _plain(&"ceramic", Color(0.95, 0.95, 0.93), 0.35)


static func coffee() -> StandardMaterial3D:
	return _plain(&"coffee", Color(0.20, 0.11, 0.06), 0.3)


## Powder-coated tumbler body.
static func tumbler() -> StandardMaterial3D:
	return _plain(&"tumbler", Color(0.36, 0.62, 0.60), 0.55, 0.1)


static func aluminium() -> StandardMaterial3D:
	return _plain(&"aluminium", Color(0.78, 0.79, 0.81), 0.35, 0.6)


static func screen_lit() -> StandardMaterial3D:
	return _plain(&"screen_lit", Color(0.16, 0.30, 0.62), 0.2, 0.0, 1.1)


## App icons on the tablet's home screen.
static func icon(index: int) -> StandardMaterial3D:
	var colours: Array[Color] = [Color(0.25, 0.85, 0.45), Color(1.0, 0.72, 0.20), Color(1.0, 0.30, 0.35), Color(0.95, 0.95, 1.0)]
	return _plain(StringName("icon_%d" % (index % 4)), colours[index % 4], 0.3, 0.0, 1.4)


static func steel() -> StandardMaterial3D:
	return _cached(&"steel", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.80, 0.83, 0.88)
		m.metallic = 0.4
		m.roughness = 0.3
		return m)


static func polymer() -> StandardMaterial3D:
	return _cached(&"polymer", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.11, 0.11, 0.14)
		m.roughness = 0.75
		return m)


static func grip_panel() -> StandardMaterial3D:
	return _cached(&"grip_panel", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.42, 0.52)
		m.roughness = 0.55
		return m)


static func wood() -> StandardMaterial3D:
	return _cached(&"wood", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.30, 0.13)
		m.roughness = 0.55
		return m)


static func wood_dark() -> StandardMaterial3D:
	return _cached(&"wood_dark", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.36, 0.16, 0.07)
		m.roughness = 0.6
		return m)


static func bakelite() -> StandardMaterial3D:
	return _cached(&"bakelite", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.50, 0.17, 0.08)
		m.roughness = 0.35
		return m)


static func parkerized() -> StandardMaterial3D:
	return _cached(&"parkerized", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.20, 0.21, 0.23)
		m.metallic = 0.3
		m.roughness = 0.55
		return m)


static func rubber() -> StandardMaterial3D:
	return _cached(&"rubber", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.06, 0.06)
		m.roughness = 1.0
		return m)


static func brass() -> StandardMaterial3D:
	return _cached(&"brass", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.78, 0.60, 0.25)
		m.metallic = 0.6
		m.roughness = 0.3
		return m)


static func bullet_black() -> StandardMaterial3D:
	return _cached(&"bullet_black", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.03, 0.03, 0.04)
		m.metallic = 0.5
		m.roughness = 0.25
		return m)


static func barrel_red() -> StandardMaterial3D:
	return _cached(&"barrel_red", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.78, 0.07, 0.05)
		m.metallic = 0.25
		m.roughness = 0.45
		return m)


static func hazard_yellow() -> StandardMaterial3D:
	return _cached(&"hazard_yellow", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.80, 0.05)
		m.roughness = 0.6
		return m)


static func white_paint() -> StandardMaterial3D:
	return _cached(&"white_paint", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.95, 0.95)
		m.roughness = 0.7
		return m)


static func visor_glass() -> StandardMaterial3D:
	return _cached(&"visor_glass", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.55, 0.92, 1.0, 0.42)
		m.emission_enabled = true
		m.emission = ACCENT
		m.emission_energy_multiplier = 0.5
		m.roughness = 0.05
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func scorch() -> StandardMaterial3D:
	return _cached(&"scorch", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.05, 0.04, 0.04, 0.72)
		return m)


static func ice() -> StandardMaterial3D:
	return _cached(&"ice", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.70, 0.90, 1.0, 0.92)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.45, 0.80, 1.0)
		m.emission_energy_multiplier = 0.35
		m.metallic = 0.2
		m.roughness = 0.08
		return m)


static var _water_shallow: ShaderMaterial
static var _water_deep: ShaderMaterial


## A wet patch of floor: a film of water. Ripples, glints and bends what is under it, no foam
## and no waves, because there is a centimetre of it.
static func water() -> ShaderMaterial:
	if _water_shallow == null:
		_water_shallow = ShaderMaterial.new()
		_water_shallow.shader = preload("res://fx/water.gdshader")
		_water_shallow.set_shader_parameter(&"wave_height", 0.0)
		_water_shallow.set_shader_parameter(&"ripple", 0.75)
		_water_shallow.set_shader_parameter(&"refraction", 0.012)
		_water_shallow.set_shader_parameter(&"foam_width", 0.0)
		_water_shallow.set_shader_parameter(&"clarity", 0.35)
		_water_shallow.set_shader_parameter(&"caustics", 0.0)
		_water_shallow.set_shader_parameter(&"shallow_color", Color(0.55, 0.78, 0.88))
		_water_shallow.set_shader_parameter(&"deep_color", Color(0.20, 0.45, 0.62))
	return _water_shallow


## The pool: two metres of it.
static func water_deep() -> ShaderMaterial:
	if _water_deep == null:
		_water_deep = ShaderMaterial.new()
		_water_deep.shader = preload("res://fx/water.gdshader")
	return _water_deep


static func splash() -> StandardMaterial3D:
	return _cached(&"splash", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.95, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		return m)


static func pool_tile() -> StandardMaterial3D:
	return _cached(&"pool_tile", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.90, 0.93)
		m.roughness = 0.35
		return m)


static func pool_line() -> StandardMaterial3D:
	return _cached(&"pool_line", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.18, 0.36)
		m.roughness = 0.4
		return m)


static func ice_floor() -> StandardMaterial3D:
	return _cached(&"ice_floor", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.82, 0.93, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.25
		m.roughness = 0.03
		return m)


## Green fog. One soft round puff on a camera-facing quad; a cloud is dozens of them overlapping.
static func fart() -> StandardMaterial3D:
	return _cached(&"fart", func() -> StandardMaterial3D:
		var falloff := Gradient.new()
		falloff.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
		falloff.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0)])
		var soft := GradientTexture2D.new()
		soft.gradient = falloff
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(1.0, 0.5)
		soft.width = 128
		soft.height = 128
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.46, 0.74, 0.10, 0.34)
		m.albedo_texture = soft
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_receive_shadows = true
		# Fog should thin out where it meets a wall or a body instead of showing a hard edge.
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.6
		# Puffs right in front of the lens vanish, or standing in the fog is a flat green screen.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 0.8
		m.distance_fade_max_distance = 4.5
		return m)


static func security_suit() -> StandardMaterial3D:
	return _cached(&"security_suit", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.07, 0.10, 0.20)
		m.roughness = 0.75
		return m)


static func shades_lens() -> StandardMaterial3D:
	return _cached(&"shades_lens", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.02, 0.02, 0.03)
		m.metallic = 0.6
		m.roughness = 0.06
		return m)


static func grenade_olive() -> StandardMaterial3D:
	return _cached(&"grenade_olive", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.27, 0.33, 0.16)
		m.metallic = 0.2
		m.roughness = 0.55
		return m)


static func fart_glow() -> StandardMaterial3D:
	return _cached(&"fart_glow", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.90, 0.12)
		m.emission_enabled = true
		m.emission = Color(0.50, 0.95, 0.10)
		m.emission_energy_multiplier = 1.4
		return m)


static func melt_pink() -> StandardMaterial3D:
	return _cached(&"melt_pink", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.30, 0.55)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.35, 0.15)
		m.emission_energy_multiplier = 1.8
		m.metallic = 0.1
		m.roughness = 0.05
		return m)


static func zombie() -> StandardMaterial3D:
	return _cached(&"zombie", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.30, 0.46)
		m.emission_enabled = true
		m.emission = Color(0.45, 0.10, 0.30)
		m.emission_energy_multiplier = 0.35
		m.roughness = 0.95
		return m)


static func hot_pink() -> StandardMaterial3D:
	return _cached(&"hot_pink", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.35, 0.72)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.25, 0.65)
		m.emission_energy_multiplier = 1.6
		m.roughness = 0.4
		return m)


static func laser() -> StandardMaterial3D:
	return _cached(&"laser", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.82, 0.45)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.10)
		m.emission_energy_multiplier = 6.0
		return m)


static func copper() -> StandardMaterial3D:
	return _cached(&"copper", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.80, 0.45, 0.25)
		m.metallic = 0.7
		m.roughness = 0.3
		return m)


static func helper_red() -> StandardMaterial3D:
	return _cached(&"helper_red", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.10, 0.08)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.10, 0.06)
		m.emission_energy_multiplier = 0.8
		m.roughness = 0.5
		return m)


static func arm() -> StandardMaterial3D:
	return _cached(&"arm", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.20, 0.21, 0.24)
		m.roughness = 0.9
		return m)


static func pink() -> StandardMaterial3D:
	return _cached(&"pink", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = PINK
		m.emission_enabled = true
		m.emission = Color(1.0, 0.12, 0.5)
		m.emission_energy_multiplier = 0.9
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
		m.albedo_color = Color(1.0, 0.18, 0.58, 0.55)
		m.emission_enabled = true
		m.emission = PINK
		m.emission_energy_multiplier = 1.6
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
