class_name Furniture
extends RefCounted
## What used to be plain boxes: the office desk and the little cabinet items wait on.
##
## Only the look changed. Each piece still collides as the same solid box it always was, so
## cover, bullets and the navmesh are exactly as before. Each model is one merged mesh. The
## first surface is the panel colour, which the level's theme recolours.

const DESK_SIZE := Vector3(1.7, 1.0, 0.9)
const CABINET_SIZE := Vector3(0.7, 0.9, 0.7)
## A 24 inch monitor each side of the desk's privacy screen. Centre of the panel, in desk space.
const MONITOR_X: float = -0.30
const MONITOR_Y: float = 0.545
const MONITOR_Z: float = 0.150
const PANEL_SIZE := Vector2(0.545, 0.325)
const SCREEN_SIZE := Vector2(0.523, 0.294)      # 16:9 inside a thin bezel


## Swaps a `LevelBuilder.make_box` body's plain box for a furniture model.
static func dress(body: StaticBody3D, mesh: ArrayMesh, panel_material: Material) -> void:
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, panel_material)
	body.add_child(mi)
	if mesh == desk_mesh():
		var screens := MeshInstance3D.new()
		screens.name = "Screens"
		screens.mesh = MonitorFeed.screens_mesh()
		screens.material_override = MonitorFeed.material(body)
		screens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(screens)


static func desk_mesh() -> ArrayMesh:
	return MeshKit.cached(&"furniture_desk", _model_desk)


static func cabinet_mesh() -> ArrayMesh:
	return MeshKit.cached(&"furniture_cabinet", _model_cabinet)


## An office desk with a privacy screen. Origin at the centre of its 1.7 x 1.0 x 0.9 box.
static func _model_desk(kit: MeshKit) -> void:
	var panel: Material = Mats.prop()          # surface 0: themed
	var top: Material = Mats.wood()
	var metal: Material = Mats.steel()
	var dark: Material = Mats.polymer()
	var floor_y: float = -0.5
	kit.box(Vector3(0.04, 0.74, 0.84), Vector3(-0.81, floor_y + 0.37, 0), panel)                # side panel
	kit.box(Vector3(0.04, 0.74, 0.84), Vector3(0.81, floor_y + 0.37, 0), panel)
	kit.box(Vector3(1.58, 0.52, 0.03), Vector3(0, floor_y + 0.46, 0.40), panel)                 # modesty panel
	kit.box(Vector3(1.58, 0.52, 0.03), Vector3(0, floor_y + 0.46, -0.40), panel)
	kit.box(Vector3(1.70, 0.045, 0.90), Vector3(0, floor_y + 0.765, 0), top)                    # the top
	kit.box(Vector3(1.70, 0.012, 0.90), Vector3(0, floor_y + 0.737, 0), dark)                   # edge band under it
	# Drawer pedestal, on both faces so it reads from either side of the room.
	for face: float in [-1.0, 1.0]:
		for i: int in 3:
			var y: float = floor_y + 0.13 + i * 0.21
			kit.box(Vector3(0.44, 0.19, 0.012), Vector3(0.52, y, 0.418 * face), top)
			kit.box(Vector3(0.14, 0.014, 0.018), Vector3(0.52, y + 0.05, 0.432 * face), metal)
	# Privacy screen along the middle, up to the full metre the collision box always had.
	kit.box(Vector3(1.62, 0.20, 0.03), Vector3(0, floor_y + 0.89, 0), panel)
	kit.box(Vector3(1.66, 0.014, 0.05), Vector3(0, floor_y + 0.993, 0), metal)
	# A monitor each side of it, and the clutter of a working desk.
	for face: float in [-1.0, 1.0]:
		# A real monitor: weighted foot, a neck with a hinge block, a thin panel with a chin.
		kit.box(Vector3(0.24, 0.010, 0.17), Vector3(MONITOR_X, floor_y + 0.793, 0.125 * face), dark)             # foot
		kit.box(Vector3(0.045, 0.235, 0.018), Vector3(MONITOR_X, floor_y + 0.905, 0.105 * face), metal)          # neck
		kit.box(Vector3(0.090, 0.070, 0.040), Vector3(MONITOR_X, floor_y + 1.030, 0.122 * face), dark)           # hinge block
		kit.box(Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.022), Vector3(MONITOR_X, MONITOR_Y, MONITOR_Z * face), dark)   # panel
		kit.box(Vector3(PANEL_SIZE.x * 0.62, PANEL_SIZE.y * 0.62, 0.020), Vector3(MONITOR_X, MONITOR_Y, (MONITOR_Z - 0.019) * face), dark)   # the bulge behind
		kit.box(Vector3(0.030, 0.004, 0.003), Vector3(MONITOR_X, MONITOR_Y - PANEL_SIZE.y * 0.5 + 0.009, (MONITOR_Z + 0.0125) * face), metal) # badge on the chin
		kit.box(Vector3(0.006, 0.004, 0.003), Vector3(MONITOR_X + 0.245, MONITOR_Y - PANEL_SIZE.y * 0.5 + 0.009, (MONITOR_Z + 0.0125) * face), Mats.icon(0))   # power light
		kit.box(Vector3(0.36, 0.014, 0.12), Vector3(-0.30, floor_y + 0.795, 0.33 * face), dark)  # keyboard
		kit.box(Vector3(0.24, 0.006, 0.31), Vector3(0.35, floor_y + 0.791, 0.24 * face), Mats.paper(), Vector3(0, 0.2 * face, 0))
	# Feet.
	for x: float in [-0.81, 0.81]:
		for z: float in [-0.38, 0.38]:
			kit.box(Vector3(0.06, 0.012, 0.06), Vector3(x, floor_y + 0.006, z), dark)


## A low storage cabinet. Origin at the centre of its 0.7 x 0.9 x 0.7 box.
static func _model_cabinet(kit: MeshKit) -> void:
	var panel: Material = Mats.prop()          # surface 0: themed
	var top: Material = Mats.wood()
	var metal: Material = Mats.steel()
	var dark: Material = Mats.polymer()
	var floor_y: float = -0.45
	kit.box(Vector3(0.66, 0.78, 0.66), Vector3(0, floor_y + 0.46, 0), panel)                    # carcass
	kit.box(Vector3(0.60, 0.07, 0.60), Vector3(0, floor_y + 0.035, 0), dark)                    # recessed plinth
	kit.box(Vector3(0.70, 0.04, 0.70), Vector3(0, floor_y + 0.88, 0), top)                      # top, overhanging
	for face: float in [-1.0, 1.0]:
		# Two doors with a shadow gap between them, and bar handles, on the front and the back.
		kit.box(Vector3(0.008, 0.72, 0.004), Vector3(0, floor_y + 0.46, 0.331 * face), dark)
		kit.box(Vector3(0.64, 0.008, 0.004), Vector3(0, floor_y + 0.83, 0.331 * face), dark)
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(0.014, 0.16, 0.016), Vector3(0.045 * side, floor_y + 0.56, 0.342 * face), metal)
		# Plain sides get a groove so they are not a blank square either.
		kit.box(Vector3(0.004, 0.008, 0.64), Vector3(0.331 * face, floor_y + 0.83, 0), dark)
