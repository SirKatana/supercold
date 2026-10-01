class_name SewerBody
extends Node3D
## One of the pink dudes who did not make it, face up in the channel and going wherever the
## water goes. He rolls, bobs, turns slowly and comes round again at the other end.
##
## Not an enemy and not a ragdoll: a Humanoid held in a slack pose, driven by arithmetic. He
## runs on world time like everything else out there, so he hangs still when the player does.

const T: Tuning = preload("res://data/tuning.tres")

## Which way the channel runs, how long it is, and where the water sits.
var along_x: bool = true
var run_length: float = 10.0
var surface_y: float = -0.8
## Where along the run he starts, and how far off the middle line he floats.
var offset: float = 0.0
var sideways: float = 0.0

var _skin: Humanoid
var _clock: float = 0.0
var _drift: float = 0.0
var _turn: float = 0.0
var _roll_phase: float = 0.0


func _ready() -> void:
	add_to_group(&"sewer_bodies")
	_skin = Humanoid.create(self, Mats.drowned_pink(), 1.0)
	_skin.set_sunglasses(false)
	_clock = randf() * 10.0
	_drift = T.sewer_drift * (0.7 + randf() * 0.6)
	_turn = (randf() - 0.5) * 0.35
	_roll_phase = randf() * TAU
	# Not posed here: the Humanoid's parts are `top_level`, and setting a global transform on
	# one before the level is in the tree pushes an error for every joint it has.


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var wd: float = TimeManager.world_delta(delta)
	if wd <= 0.0:
		_pose(0.0)      # still, but still floating where it should be
		return
	_clock += wd
	offset += _drift * wd
	# Round again at the far end, so a short stretch of sewer never runs out of bodies.
	if offset > run_length * 0.5:
		offset = -run_length * 0.5
		sideways = (randf() - 0.5) * 1.2
	_pose(wd)


## Face up, limbs spread, rolling with the water and still moving: an arm sweeps, a knee comes
## up, the body turns. Dead enough, but not a plank.
func _pose(_wd: float) -> void:
	var bob: float = sin(_clock * 0.9 + _roll_phase) * 0.05
	var roll: float = sin(_clock * 0.55 + _roll_phase) * 0.26
	var yaw: float = _turn * _clock + (0.0 if along_x else PI * 0.5)
	var along := Vector3(offset, 0, sideways) if along_x else Vector3(sideways, 0, offset)
	# High enough in the water that a shoulder and a knee are always out of it.
	position = along + Vector3(0, surface_y + 0.06 + bob, 0)

	# Lying on his back: the whole body is turned face up, then given a slow roll.
	var lying := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, roll)
	var at := Transform3D(lying, global_position)
	# A slack pose: arms out, legs apart, nothing holding itself up.
	# The arms sweep out of step with each other, which is what makes it read as moving rather
	# than as a prop lying on the water.
	var right: float = 0.45 + 0.30 * sin(_clock * 0.8 + _roll_phase)
	var left: float = 0.45 + 0.30 * sin(_clock * 0.7 + _roll_phase + 2.1)
	var kick: float = 0.12 * maxf(sin(_clock * 0.6 + _roll_phase), 0.0)
	var joints: PackedVector3Array = Humanoid.to_world(
		Humanoid.pose(kick, kick * 2.0, right, left, 0.0, true), at, 1.0)
	_skin.apply(joints)
