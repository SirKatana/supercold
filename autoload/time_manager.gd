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
## The running maximum for this frame, cleared once the frame's scale has been worked out.
var _move_speed_this_frame: float = 0.0
var _look_this_frame: float = 0.0
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


## With more than one player the world moves when **any** of them moves: the fastest one sets
## the pace. Each player reports every frame and the reports are folded together, which is why
## this takes a maximum rather than an assignment.
func report_move(horizontal_speed: float) -> void:
	_move_speed = maxf(_move_speed_this_frame, horizontal_speed)
	_move_speed_this_frame = _move_speed


func report_look(deg_per_sec: float) -> void:
	_look_deg_per_sec = maxf(_look_this_frame, deg_per_sec)
	_look_this_frame = _look_deg_per_sec


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
	# Start the next frame's fold from nothing, so a player who has stopped stops counting.
	_move_speed_this_frame = 0.0
	_look_this_frame = 0.0


func _push_to_group() -> void:
	var pitch: float = maxf(T.pitch_floor, world_scale)
	for node: Node in get_tree().get_nodes_in_group(&"time_scaled"):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.set(&"pitch_scale", pitch)
		elif &"speed_scale" in node:
			node.set(&"speed_scale", world_scale)
