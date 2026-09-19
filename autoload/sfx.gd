extends Node
## Plays synthesized sound effects. Players sit in the `time_scaled` group, so
## TimeManager bends their pitch with the world clock.

const POOL_SIZE: int = 10

var _streams: Dictionary[StringName, AudioStream] = {}
var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
var _next_flat: int = 0
var _next_spatial: int = 0


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
