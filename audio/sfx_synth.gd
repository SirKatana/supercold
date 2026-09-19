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
