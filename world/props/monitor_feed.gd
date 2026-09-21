class_name MonitorFeed
extends RefCounted
## What is on every desk monitor: the SuperCold dance video, silent. One VideoStreamPlayer
## decodes it once and every screen in the building shares its texture, so forty monitors cost
## one video. The file has no audio track. The player is in group `time_scaled`, so the video
## crawls when the world does.

const VIDEO: String = "res://world/props/monitor_loop.ogv"

static var _material: StandardMaterial3D
static var _player: VideoStreamPlayer
static var _screens: ArrayMesh


## The shared screen material. `host` is any node in the tree, used to reach the root once.
static func material(host: Node) -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.albedo_color = Color(0.9, 0.9, 0.9)
	if host != null and not host.is_inside_tree():
		# A desk is dressed before it is put in the level. Start the feed when it arrives.
		host.tree_entered.connect(func() -> void: MonitorFeed.material(host), CONNECT_ONE_SHOT)
		return _material
	if (_player == null or not is_instance_valid(_player)) and host != null:
		_player = VideoStreamPlayer.new()
		_player.name = "MonitorFeed"
		_player.stream = load(VIDEO)
		_player.loop = true
		_player.volume_db = -80.0
		_player.expand = true
		_player.size = Vector2(2, 2)
		_player.position = Vector2(-10, -10)      # off screen: only its texture is wanted
		_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_player.add_to_group(&"time_scaled")
		host.get_tree().root.add_child.call_deferred(_player)
		_player.ready.connect(func() -> void:
			_player.play()
			_material.albedo_texture = _player.get_video_texture(), CONNECT_ONE_SHOT)
	return _material


static func is_playing() -> bool:
	return _player != null and is_instance_valid(_player) and _player.is_playing()


## Both screens of a desk as one mesh: a quad facing each way, with UVs. Positions match the
## monitors modelled in `Furniture._model_desk`.
static func screens_mesh() -> ArrayMesh:
	if _screens != null:
		return _screens
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for face: float in [-1.0, 1.0]:
		var centre := Vector3(Furniture.MONITOR_X, Furniture.MONITOR_Y, (Furniture.MONITOR_Z + 0.0135) * face)
		var half := Vector2(Furniture.SCREEN_SIZE.x * 0.5, Furniture.SCREEN_SIZE.y * 0.5)
		var base: int = verts.size()
		# Seen by whoever sits on that side: their left to right is +X on the +Z face, -X on the other.
		for corner: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			verts.append(centre + Vector3(corner.x * half.x * face, corner.y * half.y, 0))
			uvs.append(Vector2(corner.x * 0.5 + 0.5, 0.5 - corner.y * 0.5))
			normals.append(Vector3(0, 0, face))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	_screens = ArrayMesh.new()
	_screens.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _screens
