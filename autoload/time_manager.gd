extends Node
## World clock. The player always runs on real delta. Everything else in the
## world multiplies its delta by `world_scale`, which rises when the player
## moves, looks around or acts, and settles to a slow crawl when they hold still.

signal scale_changed(scale: float)

const T: Tuning = preload("res://data/tuning.tres")

var world_scale: float = 1.0
## Seconds of world time since boot. Shaders read it as the global `world_time`, so water
## and anything else animated on the GPU slows down with the world.
var world_time: float = 0.0
## When >= 0 the formula is bypassed (menus, tests, hit pause).
var override_scale: float = -1.0

var _move_speed: float = 0.0
var _look_deg_per_sec: float = 0.0
var _burst_left: float = 0.0
var _burst_strength: float = 0.0
var _hit_pause_left: float = 0.0


## `burst` is the strength of any action burst in progress, 0 when there is none.
static func compute_target(move_speed: float, look_deg_per_sec: float, burst: float, t: Tuning) -> float:
	var move: float = clampf(move_speed / t.walk_speed, 0.0, 1.0)
	var look: float = clampf(look_deg_per_sec / t.look_full_deg_per_sec, 0.0, 1.0) * t.look_weight
	return maxf(t.min_scale, maxf(move, maxf(look, clampf(burst, 0.0, 1.0))))


static func step_scale(current: float, target: float, delta: float, t: Tuning) -> float:
	var rate: float = t.scale_rise_rate if target > current else t.scale_fall_rate
	return clampf(move_toward(current, target, rate * delta), t.min_scale, 1.0)


func report_move(horizontal_speed: float) -> void:
	_move_speed = horizontal_speed


func report_look(deg_per_sec: float) -> void:
	_look_deg_per_sec = deg_per_sec


func burst(seconds: float, strength: float) -> void:
	if _burst_left <= 0.0:
		_burst_strength = 0.0
	_burst_left = maxf(_burst_left, seconds)
	_burst_strength = maxf(_burst_strength, strength)


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
	_burst_strength = 0.0
	_hit_pause_left = 0.0
	world_scale = 1.0


func _process(delta: float) -> void:
	_hit_pause_left = maxf(0.0, _hit_pause_left - delta)
	var previous: float = world_scale
	if override_scale >= 0.0:
		world_scale = override_scale
	else:
		var target: float = compute_target(_move_speed, _look_deg_per_sec, _burst_strength if _burst_left > 0.0 else 0.0, T)
		world_scale = step_scale(world_scale, target, delta, T)
	_burst_left = maxf(0.0, _burst_left - delta)
	if not is_equal_approx(previous, world_scale):
		scale_changed.emit(world_scale)
	world_time += world_delta(delta)
	RenderingServer.global_shader_parameter_set(&"world_time", world_time)
	_push_to_group()


func _push_to_group() -> void:
	var pitch: float = maxf(T.pitch_floor, world_scale)
	for node: Node in get_tree().get_nodes_in_group(&"time_scaled"):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.set(&"pitch_scale", pitch)
		elif &"speed_scale" in node:
			node.set(&"speed_scale", world_scale)
