class_name WayOutArrow
extends Node3D
## The big yellow arrow that shows up once the floor is beaten and points the way to the lift.
## It floats in front of the player, bobs, and swings round to keep the lift at its point. It
## is only ever a sign: no collision, nothing to walk into, and nothing marking the lift itself.

const AHEAD: float = 3.0
const HEIGHT: float = 2.25

var target: Vector3 = Vector3.ZERO

var _bob: float = 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group(&"way_out")
	_mesh = MeshInstance3D.new()
	_mesh.mesh = MeshKit.cached(&"way_out_arrow", _model)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


## A plain 3D pointer down -Z: a cone on a round shaft, all of it yellow. Nothing clever, so
## it reads as an arrow at a glance from any side.
static func _model(kit: MeshKit) -> void:
	var yellow: Material = Mats.way_out_yellow()
	kit.tube(0.0, 0.40, 0.66, Vector3(0, 0, -0.40), yellow, true, 14)       # head
	kit.tube(0.15, 0.15, 0.70, Vector3(0, 0, 0.28), yellow, true, 12)       # shaft
	kit.tube(0.17, 0.17, 0.05, Vector3(0, 0, 0.61), yellow, true, 12)       # a little collar at the tail


func _process(delta: float) -> void:
	var player: Player = Game.player
	var showing: bool = Game.state == Game.State.CLEARED and player != null and is_instance_valid(player) and player.alive
	visible = showing
	if not showing:
		return
	_bob += delta * 2.4
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_position = player.global_position + forward.normalized() * AHEAD + Vector3(0, HEIGHT + sin(_bob) * 0.10, 0)
	var to_lift: Vector3 = target - global_position
	to_lift.y = 0.0
	if to_lift.length() > 0.2:
		# Point at the lift, lying flat, and turn slowly rather than snapping about.
		var wanted: float = atan2(-to_lift.x, -to_lift.z)
		rotation.y = lerp_angle(rotation.y, wanted, minf(1.0, delta * 6.0))
	# Nose down a little, so from behind you look along its top and see an arrow, not a bar.
	_mesh.rotation.x = -0.28
	_mesh.scale = Vector3.ONE * 1.25
	_mesh.rotation.z = sin(_bob * 1.7) * 0.10
