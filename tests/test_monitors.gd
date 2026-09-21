extends "res://tests/test_case.gd"
## Desk monitors play the dance video: one shared, silent feed that slows down with the world.


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.unload_level()


func test_every_desk_has_screens_sharing_one_silent_feed() -> void:
	check(Game.load_floor(1), "offices load")
	await wait_physics(4)
	var materials: Dictionary = {}
	var desks: int = 0
	for node: Node in Game.level.find_children("Screens", "MeshInstance3D", true, false):
		desks += 1
		materials[(node as MeshInstance3D).material_override] = true
	check(desks >= 4, "the offices are full of desks with screens, got %d" % desks)
	check_eq(materials.size(), 1, "and they all show the same picture from one material")
	var players: Array[Node] = get_tree().root.find_children("MonitorFeed", "VideoStreamPlayer", false, false)
	check_eq(players.size(), 1, "one video player for the whole building")
	var feed: VideoStreamPlayer = players[0]
	check(feed.is_playing() and feed.loop, "playing, on a loop")
	check(feed.volume_db <= -60.0, "muted")
	check(feed.is_in_group(&"time_scaled"), "and it crawls when the world does")
	check((materials.keys()[0] as StandardMaterial3D).albedo_texture != null, "the screens have the picture")


func test_the_video_file_has_no_sound_in_it() -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(MonitorFeed.VIDEO)
	check(bytes.size() > 100000, "the loop is there")
	check(bytes.get_string_from_ascii().find("vorbis") < 0 and _find(bytes, "vorbis".to_ascii_buffer()) < 0, "no audio stream inside")


func _find(haystack: PackedByteArray, needle: PackedByteArray) -> int:
	for i: int in mini(haystack.size() - needle.size(), 200000):
		if haystack.slice(i, i + needle.size()) == needle:
			return i
	return -1


func test_a_desk_is_still_a_fixed_solid_box() -> void:
	check(Game.load_floor(1), "offices load")
	await wait_physics(3)
	var desk: StaticBody3D = Game.level.find_children("Desk*", "StaticBody3D", true, false)[0]
	check_eq(desk.collision_layer, LevelBuilder.LAYER_WORLD, "world layer: bullets stop, nothing picks it up")
	check(not desk.is_in_group(&"pickups") and not desk.has_method(&"take_damage"), "not a pickup, not breakable")
	var shape: BoxShape3D = (desk.get_child(0) as CollisionShape3D).shape
	check_eq(shape.size, Furniture.DESK_SIZE, "and the same size it always was")
