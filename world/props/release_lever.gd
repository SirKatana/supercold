class_name ReleaseLever
extends StaticBody3D
## The big red lever on the basement wall. Hit it -- a punch, a bullet, anything thrown -- and
## every tank down there opens at once and what was being grown in them comes out.
##
## It only works the once, and what it lets out counts like any other enemy, so throwing it is
## a decision rather than a button to press on the way past.

signal thrown_open

const T: Tuning = preload("res://data/tuning.tres")

var used: bool = false

var _handle: Node3D
var _lamp: OmniLight3D
var _sign: Label3D


func _ready() -> void:
	add_to_group(&"release_lever")
	collision_layer = 32      # breakables: punches, bullets and thrown things all find it
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.70, 1.00, 0.34)
	shape.shape = box
	shape.position.y = 1.25
	add_child(shape)

	var plate := MeshInstance3D.new()
	plate.mesh = MeshKit.cached(&"release_lever", _model)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plate)

	_handle = Node3D.new()
	_handle.position = Vector3(0, 1.32, -0.12)
	add_child(_handle)
	var bar := MeshInstance3D.new()
	bar.mesh = MeshKit.cached(&"release_handle", _model_handle)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_handle.add_child(bar)

	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 1.95, -0.3)
	_lamp.omni_range = 3.0
	_lamp.light_energy = 0.8
	_lamp.light_color = Color(1.0, 0.25, 0.2)
	_lamp.shadow_enabled = false
	add_child(_lamp)

	_sign = Label3D.new()
	_sign.text = "CONTAINMENT RELEASE"
	_sign.font_size = 34
	_sign.pixel_size = 0.0034
	_sign.modulate = Color(1.0, 0.35, 0.3)
	_sign.shaded = false
	_sign.position = Vector3(0, 2.15, -0.2)
	add_child(_sign)


func _process(delta: float) -> void:
	if used:
		return
	# A red lamp that will not let you ignore it.
	_lamp.light_energy = 0.45 + 0.45 * absf(sin(Time.get_ticks_msec() / 400.0))
	_handle.rotation.x = lerpf(_handle.rotation.x, 0.0, clampf(delta * 4.0, 0.0, 1.0))


func on_punched(_by: Node, _at: Vector3) -> void:
	pull()


func on_thrown_hit(_item: Pickup) -> void:
	pull()


func on_bullet_hit(_bullet: Node, point: Vector3, normal: Vector3) -> bool:
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 4, Mats.barrel_red(),
		Vector3.ONE * 0.02, normal * 2.0, 0.035)
	pull()
	return false


## Every tank in the room opens. Returns how many things came out.
func pull() -> int:
	if used:
		return 0
	used = true
	_handle.rotation.x = 1.1
	_lamp.light_color = Color(0.3, 1.0, 0.45)
	_sign.text = "CONTAINMENT OPEN"
	Sfx.play(&"door_break", global_position)
	var out: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"tanks"):
		var tank: SpecimenTank = node as SpecimenTank
		if tank == null:
			continue
		if tank.let_it_out() != null:
			out += 1
	thrown_open.emit()
	return out


## A red backplate with a guard round the handle and a warning stripe under it.
static func _model(kit: MeshKit) -> void:
	var red: Material = Mats.barrel_red()
	var steel: Material = Mats.steel()
	var dark: Material = Mats.gunmetal()
	var stripe: Material = Mats.hazard_yellow()
	kit.box(Vector3(0.70, 1.00, 0.10), Vector3(0, 1.25, 0), red)
	kit.box(Vector3(0.74, 0.10, 0.12), Vector3(0, 0.78, 0), stripe)
	kit.box(Vector3(0.74, 0.10, 0.12), Vector3(0, 1.72, 0), stripe)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.07, 0.56, 0.26), Vector3(0.30 * side, 1.32, -0.12), dark)
	kit.box(Vector3(0.66, 0.07, 0.26), Vector3(0, 1.62, -0.12), dark)
	kit.tube(0.055, 0.055, 0.10, Vector3(0, 1.32, -0.03), steel, true, 10)


static func _model_handle(kit: MeshKit) -> void:
	kit.tube(0.035, 0.035, 0.34, Vector3(0, 0, -0.14), Mats.steel(), true, 8)
	kit.ball(0.075, Vector3(0, 0, -0.30), Mats.barrel_red())
