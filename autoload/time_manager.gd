extends Node
## World clock. The player always runs on real delta. Everything else in the
## world multiplies its delta by `world_scale`, which rises when the player
## moves, looks around or acts, and settles to a slow crawl when they hold still.

signal scale_changed(scale: float)

const T: Tuning = preload("res://data/tuning.tres")

var world_scale: float = 1.0
## When >= 0 the formula is bypassed (menus, tests, hit pause).
var override_scale: float = -1.0

var _move_speed: float = 0.0
var _look_deg_per_sec: float = 0.0
var _burst_left: float = 0.0
var _hit_pause_left: float = 0.0


static func compute_target(move_speed: float, look_deg_per_sec: float, bursting: bool, t: Tuning) -> float:
	var move: float = clampf(move_speed / t.walk_speed, 0.0, 1.0)
	var look: float = clampf(look_deg_per_sec / t.look_full_deg_per_sec, 0.0, 1.0) * t.look_weight
	var burst: float = 1.0 if bursting else 0.0
	return maxf(t.min_scale, maxf(move, maxf(look, burst)))


static func step_scale(current: float, target: float, delta: float, t: Tuning) -> float:
	var rate: float = t.scale_rise_rate if target > current else t.scale_fall_rate
	return clampf(move_toward(current, target, rate * delta), t.min_scale, 1.0)


func report_move(horizontal_speed: float) -> void:
	_move_speed = horizontal_speed


func report_look(deg_per_sec: float) -> void:
	_look_deg_per_sec = deg_per_sec


func burst(seconds: float) -> void:
	_burst_left = maxf(_burst_left, seconds)


## Freezes the world for a few real milliseconds. Used for kill feedback.
func hit_pause(seconds: float) -> void:
	_hit_pause_left = maxf(_hit_pause_left, seconds)


func world_delta(delta: float) -> float:
	if _hit_pause_left > 0.0:
		return 0.0
	return delta * world_scale


func reset() -> void:
	_move_speed = 0.0
	_look_deg_per_sec = 0.0
	_burst_left = 0.0
	_hit_pause_left = 0.0
	world_scale = 1.0


func _process(delta: float) -> void:
	_hit_pause_left = maxf(0.0, _hit_pause_left - delta)
	var previous: float = world_scale
	if override_scale >= 0.0:
		world_scale = override_scale
	else:
		var target: float = compute_target(_move_speed, _look_deg_per_sec, _burst_left > 0.0, T)
		world_scale = step_scale(world_scale, target, delta, T)
	_burst_left = maxf(0.0, _burst_left - delta)
	if not is_equal_approx(previous, world_scale):
		scale_changed.emit(world_scale)
	_push_to_group()


func _push_to_group() -> void:
	var pitch: float = maxf(T.pitch_floor, world_scale)
	for node: Node in get_tree().get_nodes_in_group(&"time_scaled"):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.set(&"pitch_scale", pitch)
		elif &"speed_scale" in node:
			node.set(&"speed_scale", world_scale)
