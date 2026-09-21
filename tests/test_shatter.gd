extends "res://tests/test_case.gd"
## Shards have two ways of being drawn: one MultiMesh on the desktop, plain meshes in a browser.
## Both must fly, land and clean up the same way.


func after_each() -> void:
	Shatter.plain_meshes = OS.has_feature("web")
	TimeManager.override_scale = -1.0


func _burst(plain: bool) -> Shatter:
	Shatter.plain_meshes = plain
	TimeManager.override_scale = 1.0
	var holder := Node3D.new()
	add_child(holder)
	return Shatter.burst(holder, Vector3(0, 1.5, 0), 6, Mats.door(), Vector3(0.9, 1.3, 0.05), Vector3(0, 0, -5), 0.55)


func test_desktop_shards_are_one_multimesh() -> void:
	var s: Shatter = _burst(false)
	check(s._multimesh != null and s._multimesh.instance_count == 6, "six panels in one MultiMesh")
	check_eq(s._parts.size(), 0, "and no loose meshes")
	s.get_parent().queue_free()


func test_browser_shards_are_plain_meshes_that_fly_and_clean_up() -> void:
	var s: Shatter = _burst(true)
	check(s._multimesh == null, "no MultiMesh in a browser")
	check_eq(s._parts.size(), 6, "six panels, one mesh each")
	var start: Vector3 = s._parts[0].position
	await wait_physics(20)
	check(s._parts[0].position.distance_to(start) > 0.3, "they fly")
	check(s._parts[0].position.z < start.z, "the way the door was hit")
	var holder: Node = s.get_parent()
	for i: int in int(T.shard_life * 60.0) + 30:
		await wait_physics(1)
		if not is_instance_valid(s):
			break
	check(not is_instance_valid(s), "and are gone after their time, meshes and all")
	holder.queue_free()
