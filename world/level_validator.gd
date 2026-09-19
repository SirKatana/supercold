class_name LevelValidator
extends RefCounted
## Every enemy, wave point and the exit must be walkable from the player start.
## Call after the level is in the tree and at least two physics frames have passed,
## so the navigation map has synced.

const TOLERANCE: float = 1.2


## Waits until the navigation map has picked up this level's region. Returns false on timeout.
static func wait_until_synced(level: Node3D, data: LevelData, max_frames: int = 60) -> bool:
	var region: NavigationRegion3D = level.get_node(^"Nav")
	var start: Vector3 = data.cell_center(data.player_start)
	for i: int in max_frames:
		await level.get_tree().physics_frame
		if not is_instance_valid(level):
			return false
		var map: RID = region.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, start)
			if snapped.distance_to(start) < 2.0 and NavigationServer3D.map_get_closest_point_owner(map, start) == region.get_rid():
				return true
	return false


static func unreachable(level: Node3D, data: LevelData) -> PackedStringArray:
	var problems: PackedStringArray = []
	var region: NavigationRegion3D = level.get_node(^"Nav")
	var map: RID = region.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		problems.append("navigation map never synced")
		return problems
	var start: Vector3 = data.cell_center(data.player_start)
	var targets: Dictionary[String, Vector2i] = {"exit": data.exit_cell}
	if data.boss_cell.x >= 0:
		targets["boss"] = data.boss_cell
	for i: int in data.spawns.size():
		targets["enemy %d" % i] = data.spawns[i]["cell"]
	for i: int in data.wave_points.size():
		targets["wave point %d" % i] = data.wave_points[i]
	for i: int in data.triggers.size():
		targets["trigger %d" % i] = data.triggers[i]
	for label: String in targets:
		var cell: Vector2i = targets[label]
		var goal: Vector3 = data.cell_center(cell)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, goal, true)
		var ok: bool = false
		if path.size() > 0:
			var end: Vector3 = path[path.size() - 1]
			ok = Vector2(end.x - goal.x, end.z - goal.z).length() <= TOLERANCE
		if not ok:
			var detail: String = "no path" if path.is_empty() else "path ends at %s" % str(path[path.size() - 1])
			problems.append("%s at %d,%d is not reachable from the player start (%s)" % [label, cell.x, cell.y, detail])
	return problems
