class_name CameraFx
extends Node
## Recoil kick and a small FOV punch. Runs on real time, it is the player's own body.

var camera: Camera3D

var _kick: float = 0.0
var _fov_punch: float = 0.0


func kick(radians: float) -> void:
	_kick = minf(_kick + radians, 0.12)


func punch_fov(degrees: float) -> void:
	_fov_punch = maxf(_fov_punch, degrees)


func _process(delta: float) -> void:
	if camera == null:
		return
	_kick = lerpf(_kick, 0.0, minf(1.0, delta * 14.0))
	_fov_punch = lerpf(_fov_punch, 0.0, minf(1.0, delta * 8.0))
	camera.rotation.x = _kick
	camera.fov = Settings.fov + _fov_punch
