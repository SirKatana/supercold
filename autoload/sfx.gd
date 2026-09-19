extends Node
## Plays synthesized sound effects. Players sit in the `time_scaled` group, so
## TimeManager bends their pitch with the world clock.

const POOL_SIZE: int = 10

var _streams: Dictionary[StringName, AudioStream] = {}
var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
var _next_flat: int = 0
var _next_spatial: int = 0
var _music: AudioStreamPlayer
var _music_task: int = -1
var _music_wanted: bool = false
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams = SfxSynth.build_all()
	for i: int in POOL_SIZE:
		var flat := AudioStreamPlayer.new()
		flat.add_to_group(&"time_scaled")
		add_child(flat)
		_flat.append(flat)
		var spatial := AudioStreamPlayer3D.new()
		spatial.unit_size = 8.0
		spatial.max_distance = 60.0
		spatial.add_to_group(&"time_scaled")
		add_child(spatial)
		_spatial.append(spatial)
	# Lift music is not in `time_scaled`: it plays at true pitch however slow the world is.
	_music = AudioStreamPlayer.new()
	_music.volume_db = -60.0
	add_child(_music)
	# About 150k samples of synthesis. Done on a worker thread so boot does not stall.
	_music_task = WorkerThreadPool.add_task(func() -> void:
		var stream: AudioStreamWAV = SfxSynth.build_music()
		_music.set_deferred(&"stream", stream))


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)


func _process(_delta: float) -> void:
	if _music_wanted and not _music.playing and _music.stream != null:
		_music.play()


func music_ready() -> bool:
	return _music.stream != null


func is_music_wanted() -> bool:
	return _music_wanted


func play_music() -> void:
	_music_wanted = true
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, ^"volume_db", -9.0, 0.8)


func stop_music(fade_seconds: float = 1.5) -> void:
	if not _music_wanted:
		return
	_music_wanted = false
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, ^"volume_db", -60.0, fade_seconds)
	_music_tween.tween_callback(_music.stop)


func has_sound(sound: StringName) -> bool:
	return _streams.has(sound)


## Pass a position for a sound in the world, omit it for a sound in the player's head.
func play(sound: StringName, at: Vector3 = Vector3.INF) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	if at.is_finite():
		var player: AudioStreamPlayer3D = _spatial[_next_spatial]
		_next_spatial = (_next_spatial + 1) % POOL_SIZE
		player.stream = stream
		player.global_position = at
		player.play()
	else:
		var player: AudioStreamPlayer = _flat[_next_flat]
		_next_flat = (_next_flat + 1) % POOL_SIZE
		player.stream = stream
		player.play()
