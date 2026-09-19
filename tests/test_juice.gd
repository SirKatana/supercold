extends "res://tests/test_case.gd"


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func test_every_sound_the_code_asks_for_exists() -> void:
	var asked: Dictionary[String, bool] = {}
	var regex := RegEx.new()
	regex.compile('Sfx\\.play\\(&"([a-z_]+)"')
	for dir_path: String in ["res://player", "res://weapons", "res://enemies", "res://world", "res://autoload", "res://ui"]:
		for file: String in DirAccess.get_files_at(dir_path):
			if file.ends_with(".gd"):
				for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(dir_path + "/" + file)):
					asked[m.get_string(1)] = true
	check(asked.size() >= 6, "found the play calls (%d)" % asked.size())
	for sound: String in asked:
		check(Sfx.has_sound(StringName(sound)), "no synthesized sound named '%s'" % sound)


func test_synth_streams_are_valid() -> void:
	var streams: Dictionary[StringName, AudioStream] = SfxSynth.build_all()
	for sound: StringName in streams:
		var wav: AudioStreamWAV = streams[sound]
		check(wav.data.size() > 1000, "%s has samples" % sound)
		check(wav.get_length() < 1.0, "%s is short" % sound)


func test_audio_pitch_follows_world_scale_with_floor() -> void:
	var player := AudioStreamPlayer.new()
	player.add_to_group(&"time_scaled")
	add_child(player)
	TimeManager.override_scale = 1.0
	await wait_frames(2)
	check_near(player.pitch_scale, 1.0, 0.001, "full speed pitch")
	TimeManager.override_scale = T.min_scale
	await wait_frames(2)
	check_near(player.pitch_scale, T.pitch_floor, 0.001, "pitch stops at the floor")


func test_hit_pause_freezes_world_delta_briefly() -> void:
	TimeManager.override_scale = 1.0
	await wait_frames(2)
	TimeManager.hit_pause(0.05)
	check_near(TimeManager.world_delta(0.016), 0.0, 0.0001, "world frozen during hit pause")
	await wait_frames(6)
	check(TimeManager.world_delta(0.016) > 0.0, "world resumes")


func test_recoil_kick_recovers() -> void:
	Game.god_mode = true
	check(Game.load_level("test_room"), "level loads")
	await wait_frames(2)
	Game.player.fx.kick(0.05)
	await wait_frames(1)
	check(Game.player.camera.rotation.x > 0.01, "camera kicked up")
	await wait_frames(60)
	check(absf(Game.player.camera.rotation.x) < 0.005, "camera settled")
