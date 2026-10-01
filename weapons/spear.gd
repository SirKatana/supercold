class_name Spear
extends Pickup
## A two-handed spear. Thrust, and it kills from well outside punching range. Thrown, it kills
## whatever it hits. The spearmen carry them, and you can pick one up off the floor.

var cooldown_left: float = 0.0


static func create() -> Spear:
	var s := Spear.new()
	s.kind = &"spear"
	s.name = "Spear"
	s.blunt_damage = 3
	s.throw_speed_scale = T.spear_throw_speed
	s.hold_offset = Vector3(0.02, -0.02, -0.35)
	s.flies_point_first = true      # two metres of spear has no business cartwheeling
	return s


func is_weapon() -> bool:
	return true


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"spear", _model)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Two metres of it, point at -Z.
static func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.steel()
	var wood: Material = Mats.wood()
	var wrap: Material = Mats.rubber()
	kit.tube(0.018, 0.020, 1.55, Vector3(0, 0, 0.30), wood, true, 10)                   # shaft
	for z: float in [0.05, 0.30, 0.55]:
		kit.tube(0.023, 0.023, 0.10, Vector3(0, 0, z), wrap, true, 10)                  # grip wraps
	kit.tube(0.026, 0.022, 0.09, Vector3(0, 0, -0.50), Mats.brass(), true, 10)          # collar
	kit.box(Vector3(0.020, 0.075, 0.30), Vector3(0, 0, -0.66), steel)                    # leaf blade
	kit.box(Vector3(0.020, 0.030, 0.13), Vector3(0, 0, -0.86), steel, Vector3(0.0, 0, 0))   # point
	kit.box(Vector3(0.006, 0.020, 0.26), Vector3(0, 0, -0.66), Mats.gunmetal())          # blade rib
	kit.tube(0.021, 0.014, 0.08, Vector3(0, 0, 1.06), Mats.gunmetal(), true, 10)         # butt spike


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - TimeManager.world_delta(delta))
	super(delta)


## A thrust. True if it swung, whether or not it hit.
func thrust(player: Player) -> bool:
	if cooldown_left > 0.0:
		return false
	cooldown_left = T.spear_cooldown
	var from: Vector3 = player.aim_origin()
	var dir: Vector3 = player.aim_direction()
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * T.spear_range, 1 | 4 | 32)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	Sfx.play(&"stab")
	if hit.is_empty():
		return true
	var collider: Object = hit["collider"]
	if collider is PinkDude:
		(collider as PinkDude).on_stabbed(dir)
	elif collider.has_method(&"on_punched"):
		collider.call(&"on_punched", player, hit["position"])
	return true
