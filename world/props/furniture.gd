class_name Furniture
extends RefCounted
## What used to be plain boxes: the office desk and the little cabinet items wait on.
##
## Only the look changed. Each piece still collides as the same solid box it always was, so
## cover, bullets and the navmesh are exactly as before. Each model is one merged mesh. The
## first surface is the panel colour, which the level's theme recolours.

const DESK_SIZE := Vector3(1.7, 1.0, 0.9)
const CABINET_SIZE := Vector3(0.7, 0.9, 0.7)
const PILLAR_WIDTH: float = 1.1
const SHELF_DEPTH: float = 1.0
const SHELF_HEIGHT: float = 2.4
## Floors where shelving holds stores, not books: nobody keeps a library in a furnace room.
const STORAGE_FLOORS: Array[String] = ["f7_garage", "f11_sewers", "f16_armoury", "f20_generators",
	"f24_strongrooms", "f26_morgue", "f27_furnace"]
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


## How long a run of `cells` shelving cells is. A lone one keeps the old rack's 1.7 m; each
## further cell adds a full 2 m, so a row is one unbroken unit.
static func shelf_length(cells: int) -> float:
	return cells * 2.0 - 0.3


static func shelf_size(cells: int) -> Vector3:
	return Vector3(SHELF_DEPTH, SHELF_HEIGHT, shelf_length(cells))


## A double-sided shelving unit `cells` long, running along Z. Books or stores, by floor.
static func shelf_mesh(cells: int, level_name: String) -> ArrayMesh:
	var storage: bool = level_name in STORAGE_FLOORS
	return MeshKit.cached(StringName("furniture_shelf_%d_%s" % [cells, "store" if storage else "books"]),
		_model_shelf.bind(cells, storage))


static func pillar_mesh(height: float) -> ArrayMesh:
	return MeshKit.cached(StringName("furniture_pillar_%d" % int(height * 100.0)), _model_pillar.bind(height))


## A square pillar on a cut-stone base, with a matching head under the ceiling. Origin at mid-height.
static func _model_pillar(kit: MeshKit, height: float) -> void:
	var shaft: Material = Mats.prop()           # surface 0: themed
	var stone: Material = Mats.stone()
	var w: float = PILLAR_WIDTH
	var floor_y: float = -height * 0.5
	kit.box(Vector3(w, height, w), Vector3.ZERO, shaft)
	# The base: a plinth block, then mouldings stepping in to the shaft.
	kit.box(Vector3(w + 0.26, 0.20, w + 0.26), Vector3(0, floor_y + 0.10, 0), stone)
	kit.box(Vector3(w + 0.18, 0.09, w + 0.18), Vector3(0, floor_y + 0.245, 0), stone)
	kit.box(Vector3(w + 0.10, 0.06, w + 0.10), Vector3(0, floor_y + 0.32, 0), stone)
	kit.box(Vector3(w + 0.04, 0.035, w + 0.04), Vector3(0, floor_y + 0.367, 0), stone)
	# The head, the same the other way up and a little lighter.
	kit.box(Vector3(w + 0.04, 0.035, w + 0.04), Vector3(0, -floor_y - 0.30, 0), stone)
	kit.box(Vector3(w + 0.12, 0.07, w + 0.12), Vector3(0, -floor_y - 0.245, 0), stone)
	kit.box(Vector3(w + 0.22, 0.14, w + 0.22), Vector3(0, -floor_y - 0.14, 0), stone)
	kit.box(Vector3(w + 0.22, 0.07, w + 0.22), Vector3(0, -floor_y - 0.035, 0), stone)


## Shelving open on both long faces, with a back panel down the middle. Origin at its centre.
static func _model_shelf(kit: MeshKit, cells: int, storage: bool) -> void:
	var panel: Material = Mats.prop()           # surface 0: themed
	var board: Material = Mats.steel() if storage else Mats.wood()
	var dark: Material = Mats.polymer()
	var length: float = shelf_length(cells)
	var floor_y: float = -SHELF_HEIGHT * 0.5
	var half: float = SHELF_DEPTH * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + cells * 17 + (1000 if storage else 0)

	kit.box(Vector3(SHELF_DEPTH, SHELF_HEIGHT, 0.04), Vector3(0, 0, -length * 0.5 + 0.02), panel)      # end panels
	kit.box(Vector3(SHELF_DEPTH, SHELF_HEIGHT, 0.04), Vector3(0, 0, length * 0.5 - 0.02), panel)
	kit.box(Vector3(0.02, SHELF_HEIGHT - 0.14, length - 0.08), Vector3(0, 0.03, 0), panel)             # back, down the middle
	kit.box(Vector3(SHELF_DEPTH, 0.04, length), Vector3(0, -floor_y - 0.02, 0), panel)                 # top
	kit.box(Vector3(SHELF_DEPTH - 0.06, 0.10, length - 0.04), Vector3(0, floor_y + 0.05, 0), dark)     # plinth
	var bays: int = maxi(1, int(round(length / 0.95)))
	var bay: float = (length - 0.08) / bays
	for i: int in range(1, bays):
		kit.box(Vector3(SHELF_DEPTH - 0.02, SHELF_HEIGHT - 0.14, 0.025), Vector3(0, 0.03, -length * 0.5 + 0.04 + bay * i), panel)   # uprights
	var levels: Array[float] = [0.10, 0.56, 1.02, 1.48, 1.94]
	for y: float in levels:
		kit.box(Vector3(SHELF_DEPTH - 0.02, 0.025, length - 0.08), Vector3(0, floor_y + y + 0.0125, 0), board)

	for face: float in [-1.0, 1.0]:
		for level: int in levels.size():
			var clear: float = (levels[level + 1] - levels[level] - 0.035) if level + 1 < levels.size() else 0.40
			var y0: float = floor_y + levels[level] + 0.025
			for b: int in bays:
				var z0: float = -length * 0.5 + 0.04 + bay * b + 0.025
				var z1: float = z0 + bay - 0.05
				if storage:
					_fill_with_stores(kit, rng, face, y0, clear, z0, z1, half)
				else:
					_fill_with_books(kit, rng, face, y0, clear, z0, z1, half)


## One bay of one shelf, facing `face` (-1 or +1 along X). Books stand with their spines to the room.
static func _fill_with_books(kit: MeshKit, rng: RandomNumberGenerator, face: float, y0: float, clear: float,
		z0: float, z1: float, half: float) -> void:
	var roll: float = rng.randf()
	if roll < 0.06:
		return      # an empty shelf now and then
	if roll < 0.16:
		_put_boxes(kit, rng, face, y0, clear, z0, z1, half, Mats.cardboard())
		return
	if roll < 0.24:
		_put_ornament(kit, rng, face, y0, (z0 + z1) * 0.5, half)
		z1 = (z0 + z1) * 0.5 - 0.16      # books fill what is left of the bay
	var z: float = z0
	var stop: float = z1 - rng.randf_range(0.0, 0.28)
	var colour: int = rng.randi()
	while z < stop:
		var thick: float = rng.randf_range(0.032, 0.075)
		if z + thick > stop:
			break
		var tall: float = minf(clear - 0.02, rng.randf_range(0.22, 0.34))
		var deep: float = rng.randf_range(0.17, 0.23)
		if rng.randf() < 0.75:
			colour = rng.randi()      # runs of the same binding happen, but not often
		var x: float = face * (half - 0.035 - deep * 0.5)
		kit.box(Vector3(deep, tall, thick - 0.004), Vector3(x, y0 + tall * 0.5, z + thick * 0.5), Mats.book(colour))
		if thick > 0.05 and rng.randf() < 0.5:      # a title band on the fatter spines
			kit.box(Vector3(0.004, tall * 0.16, thick - 0.012), Vector3(face * (half - 0.033), y0 + tall * 0.72, z + thick * 0.5), Mats.brass())
		z += thick
	# What would not stand goes flat in a pile at the end.
	if z1 - z > 0.26 and rng.randf() < 0.6:
		var pile_y: float = y0
		for k: int in rng.randi_range(2, 4):
			var t: float = rng.randf_range(0.03, 0.055)
			kit.box(Vector3(0.20, t - 0.003, 0.24), Vector3(face * (half - 0.14), pile_y + t * 0.5, z + 0.15), Mats.book(rng.randi()), Vector3(0, rng.randf_range(-0.12, 0.12), 0))
			pile_y += t


static func _put_boxes(kit: MeshKit, rng: RandomNumberGenerator, face: float, y0: float, clear: float,
		z0: float, z1: float, half: float, material: Material) -> void:
	var z: float = z0 + 0.02
	while z < z1 - 0.2:
		var wide: float = rng.randf_range(0.24, 0.38)
		if z + wide > z1:
			break
		var tall: float = minf(clear - 0.03, rng.randf_range(0.18, 0.32))
		kit.box(Vector3(0.34, tall, wide - 0.02), Vector3(face * (half - 0.21), y0 + tall * 0.5, z + wide * 0.5), material)
		kit.box(Vector3(0.004, tall * 0.35, (wide - 0.02) * 0.55), Vector3(face * (half - 0.038), y0 + tall * 0.55, z + wide * 0.5), Mats.paper())   # label
		z += wide + rng.randf_range(0.01, 0.06)


static func _put_ornament(kit: MeshKit, rng: RandomNumberGenerator, face: float, y0: float, z: float, half: float) -> void:
	var x: float = face * (half - 0.16)
	match rng.randi_range(0, 2):
		0:      # a globe on a stand
			kit.tube(0.05, 0.06, 0.02, Vector3(x, y0 + 0.01, z), Mats.wood_dark(), false, 12)
			kit.tube(0.008, 0.008, 0.07, Vector3(x, y0 + 0.05, z), Mats.brass(), false, 6)
			kit.ball(0.085, Vector3(x, y0 + 0.17, z), Mats.book(1))
		1:      # a plant
			kit.tube(0.075, 0.055, 0.11, Vector3(x, y0 + 0.055, z), Mats.ceramic(), false, 12)
			kit.ball(0.10, Vector3(x, y0 + 0.20, z), Mats.leaf_green(), Vector3(1.0, 1.15, 1.0))
			kit.ball(0.06, Vector3(x + 0.05 * face, y0 + 0.27, z + 0.04), Mats.leaf_green())
		_:      # a trophy
			kit.box(Vector3(0.09, 0.03, 0.09), Vector3(x, y0 + 0.015, z), Mats.wood_dark())
			kit.tube(0.012, 0.02, 0.08, Vector3(x, y0 + 0.07, z), Mats.brass(), false, 8)
			kit.tube(0.055, 0.02, 0.09, Vector3(x, y0 + 0.155, z), Mats.brass(), false, 10)


## Stores: crates, cartons, drums and toolboxes, on steel shelves.
static func _fill_with_stores(kit: MeshKit, rng: RandomNumberGenerator, face: float, y0: float, clear: float,
		z0: float, z1: float, half: float) -> void:
	var roll: float = rng.randf()
	if roll < 0.12:
		return
	if roll < 0.55:
		_put_boxes(kit, rng, face, y0, clear, z0, z1, half, Mats.cardboard() if rng.randf() < 0.6 else Mats.wood())
		return
	var z: float = z0 + 0.08
	while z < z1 - 0.1:
		var tall: float = minf(clear - 0.04, rng.randf_range(0.20, 0.34))
		if rng.randf() < 0.6:      # a drum or a can
			var r: float = rng.randf_range(0.07, 0.11)
			kit.tube(r, r, tall, Vector3(face * (half - 0.18), y0 + tall * 0.5, z + r), [Mats.steel(), Mats.book(1), Mats.book(3), Mats.polymer()][rng.randi_range(0, 3)], false, 12)
			kit.tube(r * 1.03, r * 1.03, 0.02, Vector3(face * (half - 0.18), y0 + tall - 0.01, z + r), Mats.polymer(), false, 12)
			z += r * 2.0 + rng.randf_range(0.02, 0.10)
		else:      # a toolbox
			kit.box(Vector3(0.22, 0.16, 0.36), Vector3(face * (half - 0.16), y0 + 0.08, z + 0.18), Mats.book(0))
			kit.box(Vector3(0.03, 0.025, 0.16), Vector3(face * (half - 0.16), y0 + 0.175, z + 0.18), Mats.polymer())
			z += 0.36 + rng.randf_range(0.03, 0.10)


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
