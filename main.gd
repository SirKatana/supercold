extends Node3D
## Entry scene. Builds environment, light and HUD, then hands over to Game.

const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")


func _ready() -> void:
	_build_environment()
	var root := Node3D.new()
	root.name = "LevelRoot"
	add_child(root)
	Game.level_root = root
	add_child(HUD_SCENE.instantiate())
	Game.load_level(_arg("level", "test_room"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _arg("shot", "") != "":
		_capture.call_deferred(_arg("shot", ""), float(_arg("shot-after", "1.0")))


## Reads `--name=value` from the arguments after `--` on the command line.
func _arg(arg_name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.trim_prefix("--%s=" % arg_name)
	return fallback


## Debug aid: `godot4 --path . -- --shot=/tmp/f.png --shot-after=1.5` saves one frame and quits.
func _capture(path: String, after: float) -> void:
	await get_tree().create_timer(after, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.94, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.35
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = false
	add_child(sun)
