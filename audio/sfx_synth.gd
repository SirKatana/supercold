class_name SfxSynth
extends RefCounted
## Every sound in the game is generated here at boot. No audio files.

const RATE: int = 22050


static func build_all() -> Dictionary[StringName, AudioStream]:
	return {
		&"shot": _render(0.28, func(t: float, n: float) -> float:
			return (n * exp(-t * 38.0) * 0.9 + sin(TAU * (160.0 - t * 300.0) * t) * exp(-t * 14.0) * 0.8)),
		&"shatter": _render(0.55, func(t: float, n: float) -> float:
			var grain: float = 1.0 if fmod(t * 90.0, 1.0) < 0.35 else 0.25
			return n * grain * exp(-t * 7.0) * 0.8 + sin(TAU * 2400.0 * t) * exp(-t * 30.0) * 0.25),
		&"punch": _render(0.14, func(t: float, n: float) -> float:
			return sin(TAU * (120.0 - t * 400.0) * t) * exp(-t * 26.0) + n * exp(-t * 90.0) * 0.4),
		&"pickup": _render(0.09, func(t: float, _n: float) -> float:
			return sin(TAU * (700.0 + t * 5000.0) * t) * exp(-t * 30.0) * 0.5),
		&"throw": _render(0.22, func(t: float, n: float) -> float:
			return n * sin(PI * t / 0.22) * 0.35 * (0.5 + 0.5 * sin(TAU * 40.0 * t))),
		&"door_hit": _render(0.18, func(t: float, n: float) -> float:
			return sin(TAU * 90.0 * t) * exp(-t * 22.0) + n * exp(-t * 60.0) * 0.3),
		&"door_break": _render(0.6, func(t: float, n: float) -> float:
			return n * exp(-t * 6.0) * 0.8 + sin(TAU * 70.0 * t) * exp(-t * 9.0) * 0.7),
		&"ding": _render(0.8, func(t: float, _n: float) -> float:
			var second: float = sin(TAU * 1318.5 * (t - 0.18)) * exp(-(t - 0.18) * 5.0) if t > 0.18 else 0.0
			return (sin(TAU * 1046.5 * t) * exp(-t * 5.0) + second) * 0.4),
		&"death": _render(0.8, func(t: float, n: float) -> float:
			return sin(TAU * (300.0 - t * 280.0) * t) * exp(-t * 3.0) * 0.6 + n * exp(-t * 12.0) * 0.3),
	}


static func _render(seconds: float, wave: Callable) -> AudioStreamWAV:
	var count: int = int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i: int in count:
		var t: float = float(i) / RATE
		var sample: float = clampf(wave.call(t, rng.randf_range(-1.0, 1.0)), -1.0, 1.0)
		# Short fade at the tail so nothing clicks.
		sample *= clampf((count - i) / 200.0, 0.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Lift music: a slow four-chord loop with soft electric piano, a walking root, a light
## shaker and a wandering pentatonic melody. 16 beats at 100 bpm, loops seamlessly.
static func build_music() -> AudioStreamWAV:
	var rate: int = 16000
	var beat: float = 0.6
	var beats: int = 16
	var count: int = int(beat * beats * rate)
	var chords: Array[PackedFloat32Array] = [
		PackedFloat32Array([261.63, 329.63, 392.00, 493.88]),   # Cmaj7
		PackedFloat32Array([220.00, 261.63, 329.63, 392.00]),   # Am7
		PackedFloat32Array([293.66, 349.23, 440.00, 523.25]),   # Dm7
		PackedFloat32Array([196.00, 246.94, 293.66, 349.23]),   # G7
	]
	var melody: PackedFloat32Array = PackedFloat32Array([
		659.25, 0, 587.33, 523.25, 0, 440.0, 523.25, 0, 587.33, 0, 698.46, 659.25, 0, 587.33, 493.88, 0,
		523.25, 0, 0, 659.25, 783.99, 0, 659.25, 0, 587.33, 523.25, 0, 440.0, 392.0, 0, 493.88, 0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / rate
		var beat_index: int = int(t / beat)
		var chord: PackedFloat32Array = chords[(beat_index / 4) % 4]
		var in_beat: float = t - beat_index * beat
		# Electric piano: chord struck on beats 1 and 3, a lighter touch on 2 and 4.
		var strike: float = exp(-in_beat * 3.2) * (1.0 if beat_index % 2 == 0 else 0.55)
		var keys: float = 0.0
		for f: float in chord:
			keys += sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-in_beat * 6.0)
		var bass: float = sin(TAU * chord[0] * 0.5 * t) * exp(-in_beat * 2.0)
		var half: int = int(t / (beat * 0.5))
		var in_half: float = t - half * beat * 0.5
		var note: float = melody[half % melody.size()]
		var lead: float = 0.0
		if note > 0.0:
			var tri: float = 2.0 * absf(2.0 * fmod(note * t, 1.0) - 1.0) - 1.0
			lead = tri * exp(-in_half * 5.0)
		var shaker: float = rng.randf_range(-1.0, 1.0) * exp(-in_half * 45.0) * (0.6 if half % 2 == 1 else 0.3)
		var sample: float = keys * strike * 0.085 + bass * 0.22 + lead * 0.13 + shaker * 0.05
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
