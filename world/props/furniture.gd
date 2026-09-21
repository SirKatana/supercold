class_name Furniture
extends RefCounted
## What used to be plain boxes: the office desk and the little cabinet items wait on.
##
## Only the look changed. Each piece still collides as the same solid box it always was, so
## cover, bullets and the navmesh are exactly as before. Each model is one merged mesh. The
## first surface is the panel colour, which the level's theme recolours.

const DESK_SIZE := Vector3(1.7, 1.0, 0.9)
const CABINET_SIZE := Vector3(0.7, 0.9, 0.7)


## Swaps a `LevelBuilder.make_box` body's plain box for a furniture model.
static func dress(body: StaticBody3D, mesh: ArrayMesh, panel_material: Material) -> void:
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, panel_material)
	body.add_child(mi)


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
		kit.box(Vector3(0.20, 0.012, 0.14), Vector3(-0.30, floor_y + 0.794, 0.20 * face), dark)  # stand foot
		kit.box(Vector3(0.035, 0.12, 0.02), Vector3(-0.30, floor_y + 0.85, 0.15 * face), dark)   # neck
		kit.box(Vector3(0.50, 0.19, 0.022), Vector3(-0.30, floor_y + 0.895, 0.125 * face), dark) # screen
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
