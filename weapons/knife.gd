class_name Knife
extends Pickup
## Combat knife. One stab kills an ordinary dude. Thrown, it kills too.

var cooldown_left: float = 0.0


static func create() -> Knife:
	var k := Knife.new()
	k.kind = &"knife"
	k.name = "Knife"
	k.blunt_damage = 3
	k.hold_offset = Vector3(0.0, 0.012, -0.05)
	k.hold_euler = Vector3(-0.22, 0.14, 0.30)
	return k


func is_weapon() -> bool:
	return true


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"knife", _model)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.steel()
	var dark: Material = Mats.polymer()
	var wrap: Material = Mats.rubber()
	kit.box(Vector3(0.004, 0.036, 0.170), Vector3(0, 0.0, -0.135), steel)                     # blade
	kit.box(Vector3(0.0045, 0.020, 0.060), Vector3(0, 0.004, -0.235), steel, Vector3(0.22, 0, 0))   # clip point
	kit.box(Vector3(0.0055, 0.008, 0.150), Vector3(0, 0.016, -0.130), Mats.gunmetal())        # spine
	kit.box(Vector3(0.0015, 0.004, 0.110), Vector3(0.003, 0.004, -0.130), dark)               # fuller
	for i: int in 5:                                                                          # serrations
		kit.box(Vector3(0.0045, 0.006, 0.006), Vector3(0, 0.020, -0.075 - i * 0.012), steel, Vector3(0.7, 0, 0))
	kit.box(Vector3(0.014, 0.060, 0.012), Vector3(0, 0.0, -0.044), Mats.gunmetal())           # guard
	kit.box(Vector3(0.024, 0.030, 0.105), Vector3(0, 0.0, 0.014), dark)                        # handle
	for i: int in 6:
		kit.box(Vector3(0.026, 0.032, 0.006), Vector3(0, 0.0, -0.026 + i * 0.016), wrap)      # grip rings
	kit.box(Vector3(0.026, 0.034, 0.014), Vector3(0, 0.0, 0.072), Mats.gunmetal())            # pommel
	kit.tube(0.004, 0.004, 0.028, Vector3(0, 0.0, 0.072), steel, false, 8, Vector3(0, 0, PI * 0.5))   # lanyard hole


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - TimeManager.world_delta(delta))
	super(delta)


## Returns true if it swung.
func stab(player: Player) -> bool:
	if cooldown_left > 0.0:
		return false
	cooldown_left = T.knife_cooldown
	var from: Vector3 = player.aim_origin()
	var dir: Vector3 = player.aim_direction()
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * T.knife_range, 1 | 4 | 32)
	query.collide_with_areas = true       # fart clouds and barrels are areas
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
