class_name Throwable
extends Pickup
## Office junk. Everything here is a one-shot stun when thrown.

const FRAGILE_KINDS: Array[StringName] = [&"bottle", &"mug"]


static func create(item_kind: StringName) -> Throwable:
	var t := Throwable.new()
	t.kind = item_kind
	t.fragile = item_kind in FRAGILE_KINDS
	t.name = String(item_kind).capitalize()
	# A mug is held by its handle, not by the middle of the cup. The handle stands at
	# (0.072, 0.004) in the model, so the mug hangs off to the left of the fist.
	if item_kind == &"mug":
		t.hold_offset = Vector3(-0.072, -0.004, 0.0)
		t.hold_euler = Vector3(0.0, 0.0, -0.12)
	elif item_kind == &"bottle":
		# Round the body, a third of the way up, the way anybody holds a flask.
		t.hold_offset = Vector3(0.0, -0.09, 0.0)
	return t


func _build_mesh(root: Node3D) -> void:
	match kind:
		&"bottle":
			_add_model(root, MeshKit.cached(&"throw_tumbler", _model_tumbler))
		&"mug":
			_add_model(root, MeshKit.cached(&"throw_mug", _model_mug))
		&"keyboard":
			# The level files still say keyboard. What lies there now is a tablet.
			_add_model(root, MeshKit.cached(&"throw_tablet", _model_tablet))
		&"stapler":
			add_box(root, Vector3(0.06, 0.06, 0.17), Vector3.ZERO)
		_:
			add_box(root, Vector3.ONE * 0.15, Vector3.ZERO)


## A mug goes, and what was in it goes on the floor.
func shatter() -> void:
	if kind == &"mug":
		var spill := Puddle.new()
		spill.name = "Coffee"
		spill.coffee = true
		spill.radius = T.coffee_radius
		spill.life = T.coffee_seconds
		Game.entities_root(self).add_child(spill)
		spill.global_position = Vector3(global_position.x, 0.0, global_position.z)
		Game.report_spill(spill)
	super()


func shard_material() -> Material:
	return Mats.tumbler() if kind == &"bottle" else Mats.ceramic() if kind == &"mug" else Mats.black()


func _add_model(root: Node3D, mesh: Mesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## The big insulated tumbler everybody carries: narrow foot for the cup holder, wide body,
## a steel rim, a dark lid with a straw, and a side handle. The base sits 5 cm under the origin.
static func _model_tumbler(kit: MeshKit) -> void:
	var body: Material = Mats.tumbler()
	var metal: Material = Mats.steel()
	var lid: Material = Mats.polymer()
	var y0: float = -0.05
	kit.tube(0.036, 0.034, 0.105, Vector3(0, y0 + 0.0525, 0), body, false, 16)       # the foot
	kit.tube(0.050, 0.036, 0.030, Vector3(0, y0 + 0.120, 0), body, false, 16)        # the flare
	kit.tube(0.052, 0.050, 0.150, Vector3(0, y0 + 0.210, 0), body, false, 16)        # the body
	kit.tube(0.0535, 0.0535, 0.012, Vector3(0, y0 + 0.291, 0), metal, false, 16)     # steel rim
	kit.tube(0.050, 0.053, 0.022, Vector3(0, y0 + 0.308, 0), lid, false, 16)         # lid
	kit.tube(0.006, 0.006, 0.150, Vector3(0.012, y0 + 0.380, 0), Mats.ceramic(), false, 8, Vector3(0, 0, -0.10))   # straw
	# Handle: two arms and a grip.
	kit.box(Vector3(0.050, 0.016, 0.026), Vector3(0.072, y0 + 0.270, 0), lid)
	kit.box(Vector3(0.050, 0.016, 0.026), Vector3(0.072, y0 + 0.150, 0), lid)
	kit.box(Vector3(0.018, 0.136, 0.030), Vector3(0.098, y0 + 0.210, 0), body)


static func _model_mug(kit: MeshKit) -> void:
	var y0: float = -0.05
	kit.tube(0.046, 0.042, 0.100, Vector3(0, y0 + 0.050, 0), Mats.ceramic(), false, 16)
	kit.tube(0.040, 0.040, 0.004, Vector3(0, y0 + 0.099, 0), Mats.coffee(), false, 16)
	kit.box(Vector3(0.030, 0.012, 0.014), Vector3(0.058, y0 + 0.078, 0), Mats.ceramic())
	kit.box(Vector3(0.030, 0.012, 0.014), Vector3(0.058, y0 + 0.030, 0), Mats.ceramic())
	kit.box(Vector3(0.012, 0.060, 0.014), Vector3(0.072, y0 + 0.054, 0), Mats.ceramic())


## A tablet lying on its back with the home screen on: aluminium shell, black glass, a grid of
## app icons and a dock.
static func _model_tablet(kit: MeshKit) -> void:
	kit.box(Vector3(0.250, 0.008, 0.180), Vector3(0, 0.000, 0), Mats.aluminium())
	kit.box(Vector3(0.246, 0.003, 0.176), Vector3(0, 0.0055, 0), Mats.polymer())        # glass and bezel
	kit.box(Vector3(0.226, 0.001, 0.156), Vector3(0, 0.0075, 0), Mats.screen_lit())     # the screen
	for row: int in 3:
		for column: int in 5:
			kit.box(Vector3(0.026, 0.001, 0.026), Vector3(-0.084 + column * 0.042, 0.0085, -0.052 + row * 0.040), Mats.icon(row * 5 + column + row))
	kit.box(Vector3(0.150, 0.001, 0.030), Vector3(0, 0.0083, 0.060), Mats.aluminium())   # the dock
	for column: int in 4:
		kit.box(Vector3(0.022, 0.001, 0.022), Vector3(-0.048 + column * 0.032, 0.0092, 0.060), Mats.icon(column + 2))
	kit.tube(0.003, 0.003, 0.002, Vector3(0, 0.0072, -0.083), Mats.steel(), false, 8)    # camera
