extends Node
## Sound effects. Filled in at M7; until then play() is a safe no-op.

var _streams: Dictionary[StringName, AudioStream] = {}


func play(_sound: StringName, _at: Vector3 = Vector3.INF) -> void:
	pass
