extends "res://tests/test_case.gd"
## The browser build folds each model's plain materials into one vertex-coloured surface, so a
## model is one or two draw calls instead of one per material.


func after_each() -> void:
	MeshKit.colour_merge = OS.has_feature("web")


func _bake(build: Callable) -> ArrayMesh:
	var kit := MeshKit.new()
	build.call(kit)
	return kit.bake()


func test_a_door_leaf_becomes_one_draw_call_with_its_colours_kept() -> void:
	MeshKit.colour_merge = false
	var before: ArrayMesh = _bake(Door._model_leaf)
	MeshKit.colour_merge = true
	var after: ArrayMesh = _bake(Door._model_leaf)
	check(before.get_surface_count() >= 4, "separately it is one per material, got %d" % before.get_surface_count())
	check_eq(after.get_surface_count(), 1, "merged, it is one")
	var arrays: Array = after.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	check_eq(colours.size(), (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "a colour on every vertex")
	var has: Callable = func(want: Color) -> bool:
		for c: Color in colours:
			if absf(c.r - want.r) < 0.01 and absf(c.g - want.g) < 0.01 and absf(c.b - want.b) < 0.01:      # stored at 8 bits a channel
				return true
		return false
	check(has.call(Mats.wood().albedo_color) and has.call(Mats.steel().albedo_color), "wood still wood, steel still steel")
	check((after.surface_get_material(0) as StandardMaterial3D).vertex_color_use_as_albedo, "drawn with its vertex colours")


func test_the_themed_panel_stays_surface_zero_and_glow_stays_apart() -> void:
	MeshKit.colour_merge = true
	var desk: ArrayMesh = _bake(Furniture._model_desk)
	check_eq(desk.surface_get_material(0), Mats.prop(), "the level theme can still recolour the panels")
	check_eq(desk.get_surface_count(), 3, "panels, the monitors' glowing power lights, and everything else in one")
	var tablet: ArrayMesh = _bake(Throwable._model_tablet)
	var glowing: int = 0
	for s: int in tablet.get_surface_count():
		var m: StandardMaterial3D = tablet.surface_get_material(s)
		if m.emission_enabled:
			glowing += 1
	check(glowing >= 1, "the lit screen and icons keep their glow")
	check(tablet.get_surface_count() < 8, "and the plain parts are merged, got %d" % tablet.get_surface_count())
