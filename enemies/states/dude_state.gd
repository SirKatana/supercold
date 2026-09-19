class_name DudeState
extends RefCounted
## Base FSM state. `time` is world time spent in the state.

const T: Tuning = preload("res://data/tuning.tres")

var dude: PinkDude
var time: float = 0.0


func enter() -> void:
	pass


func exit() -> void:
	pass


## Returns the next state name, or an empty name to stay.
func update(_wd: float) -> StringName:
	return &""
