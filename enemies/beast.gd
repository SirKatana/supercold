class_name Beast
extends PinkDude
## What they were growing in the basement, and it is not a boss: there is no bar, no name over
## the room, and no standing fight in the middle of the floor. It is loose in the building.
##
## Most of the time it is not a body at all. It runs as a puddle of itself along the floor and
## through the ducts, flat and quick and quiet, and you can walk past it. When it is close
## enough and has you in sight it pours back up into a shape: squat, wide, red over green, and
## on you in under a second. Hurt it and it collapses back into liquid and leaves, and it comes
## again from somewhere else. `beast_hp` in total, however many times that takes.

signal poured_away
signal rose_up

enum Form { LIQUID, RISING, SOLID, SINKING }

var form: Form = Form.LIQUID
var hp_left: int = 26

var _charge_clock: float = 0.0
var _charging: float = -1.0
var _charge_dir: Vector3 = Vector3.ZERO
var _gradient: ShaderMaterial
var _slick: MeshInstance3D
var _form_clock: float = 0.0
var _patience: float = 0.0
var _went_under: Vector3 = Vector3.ZERO
var _hits_this_form: int = 0


func _ready() -> void:
	body_scale = T.beast_scale
	armed_at_spawn = false
	_gradient = ShaderMaterial.new()
	_gradient.shader = preload("res://fx/gradient.gdshader")
	_gradient.set_shader_parameter(&"low_colour", Color(0.10, 0.90, 0.22))
	_gradient.set_shader_parameter(&"high_colour", Color(0.95, 0.08, 0.10))
	_gradient.set_shader_parameter(&"span", 1.6 * T.beast_scale)
	body_material = _gradient
	super()
	hp_left = T.beast_hp
	seeks_weapons = false
	skin.set_sunglasses(false)
	_charge_clock = T.beast_charge_every * 0.6
	# What it looks like while it is liquid: a low slick of itself, spreading and drawing in.
	_slick = MeshInstance3D.new()
	_slick.mesh = MeshKit.cached(&"beast_slick", _model_slick)
	_slick.material_override = _gradient
	_slick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_slick)
	_become(Form.LIQUID)


## A flat pool with a raised middle, so it reads as something and not a decal.
static func _model_slick(kit: MeshKit) -> void:
	var skin_material: Material = Mats.specimen()
	kit.tube(0.62, 0.78, 0.055, Vector3(0, 0.028, 0), skin_material, false, 20)
	kit.tube(0.30, 0.52, 0.075, Vector3(0, 0.075, 0), skin_material, false, 18)
	kit.ball(0.22, Vector3(0, 0.11, 0), skin_material, Vector3(1.4, 0.45, 1.4))
	for i: int in 5:
		var angle: float = TAU * i / 5.0 + 0.3
		kit.ball(0.14, Vector3(cos(angle) * 0.62, 0.03, sin(angle) * 0.62), skin_material, Vector3(1.2, 0.28, 1.2))


func voice_name_id() -> StringName:
	return &"name_beast"


func liquid() -> bool:
	return form == Form.LIQUID or form == Form.SINKING


func wears_shades() -> bool:
	return false


func seeks_cover() -> bool:
	return false


func can_freeze() -> bool:
	return false


func can_choke() -> bool:
	return false


func can_slip() -> bool:
	return false


func move_speed() -> float:
	if form == Form.LIQUID:
		return T.beast_liquid_speed
	return T.beast_charge_speed if _charging >= 0.0 else T.beast_speed


func punch_range() -> float:
	return T.beast_swipe_range


func punch_windup() -> float:
	return T.beast_swipe_windup


func punch_sound() -> StringName:
	return &"slam"


func freeze(_seconds: float) -> void:
	stun(1.2)


func disarm() -> void:
	pass


## Nothing can touch it while it is a puddle: it has no shape to hit.
func _become(next: Form) -> void:
	form = next
	_form_clock = 0.0
	var is_liquid: bool = next == Form.LIQUID
	skin.visible = not is_liquid
	_slick.visible = is_liquid or next == Form.RISING or next == Form.SINKING
	collision_layer = 0 if is_liquid else 4
	# As a slick it is low enough to go under a duct's roof and thin enough to seep past a
	# grate: the navmesh stops at the wall, so a liquid has to move itself.
	if _capsule != null:
		_capsule.height = 0.45 if is_liquid else 1.8 * body_scale
	if _body_shape != null:
		_body_shape.position.y = 0.22 if is_liquid else 0.9 * body_scale
	if next == Form.LIQUID:
		_patience = randf_range(T.beast_hide_min, T.beast_hide_max)
		poured_away.emit()
	elif next == Form.SOLID:
		_hits_this_form = 0
		rose_up.emit()


func _physics_process(delta: float) -> void:
	super(delta)
	# The gradient is taken from world height, so it has to follow it up and down.
	_gradient.set_shader_parameter(&"base_y", global_position.y)
	if not alive:
		return
	var wd: float = TimeManager.world_delta(delta)
	_form_clock += wd
	match form:
		Form.LIQUID:
			_run_as_liquid(wd)
			return
		Form.RISING:
			# Pouring upward into a shape. Helpless for a moment, and loud about it.
			var up: float = clampf(_form_clock / T.beast_rise_seconds, 0.0, 1.0)
			_slick.scale = Vector3(1.0 - up * 0.7, 1.0 + up * 2.0, 1.0 - up * 0.7)
			skin.visible = up > 0.35
			if up >= 1.0:
				_slick.scale = Vector3.ONE
				_become(Form.SOLID)
			return
		Form.SINKING:
			var down: float = clampf(_form_clock / T.beast_sink_seconds, 0.0, 1.0)
			skin.visible = down < 0.3
			_slick.scale = Vector3(0.4 + down * 0.6, 1.4 - down * 1.2, 0.4 + down * 0.6)
			if down >= 1.0:
				_slick.scale = Vector3.ONE
				_become(Form.LIQUID)
			return
	if stunned:
		_charging = -1.0
		return
	if _charging >= 0.0:
		_charging += wd
		desired_velocity = _charge_dir * T.beast_charge_speed
		face_toward(global_position + _charge_dir, wd)
		var p: Player = get_player()
		if p != null and p.alive and flat_distance_to(p.global_position) <= T.beast_swipe_range * 0.8:
			p.hit_from(p.global_position - global_position, display_name())
		if _charging >= 1.1 or is_on_wall():
			_charging = -1.0
			_charge_clock = T.beast_charge_every
			stun(T.beast_wall_stun)      # he goes into the wall and it takes him a moment
			Sfx.play(&"slam", global_position)
			Shatter.burst(Game.entities_root(self), global_position + Vector3(0, 1.4, 0), 10, Mats.floor_mat(),
				Vector3(0.6, 0.4, 0.6), Vector3.UP * 2.0, 0.14)
			var watcher: Player = get_player()
			if watcher != null:
				watcher.fx.shake(0.08)
		return
	_charge_clock -= wd
	if _charge_clock <= 0.0 and can_see_player and dist_to_player <= T.beast_charge_range and dist_to_player > T.beast_swipe_range:
		_charging = 0.0
		_charge_dir = (player_position() - global_position) * Vector3(1, 0, 1)
		_charge_dir = _charge_dir.normalized() if _charge_dir.length() > 0.1 else -global_transform.basis.z
		Sfx.play(&"choke", global_position)


## Where it goes when it has had enough for the moment: a duct if there is one on this floor,
## otherwise a dark corner well away from the player.
## Straight there, along the floor, through whatever will let it past. A navmesh agent cannot
## enter a duct -- the tunnel is shorter than the agent -- so the liquid does not use one.
func _seep_toward(target: Vector3, wd: float) -> void:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() < 0.15:
		desired_velocity = Vector3.ZERO
		return
	desired_velocity = flat.normalized() * T.beast_liquid_speed
	if flat.length() > 0.5:
		look_at(Vector3(target.x, global_position.y, target.z))
	# It is moved here rather than by the dude's own walk, which goes through the navmesh.
	var step: Vector3 = desired_velocity * wd
	var collided: KinematicCollision3D = move_and_collide(step)
	if collided != null:
		# Round whatever is in the way: a slick finds the gap rather than stopping at it.
		move_and_collide(step.slide(collided.get_normal()))


func _somewhere_to_hide() -> Vector3:
	var ducts: Array[Vector2i] = []
	if Game.data != null:
		for y: int in Game.data.height:
			for x: int in Game.data.width:
				if Game.data.rows[y][x] == "v" or Game.data.rows[y][x] == "e":
					ducts.append(Vector2i(x, y))
	var from: Vector3 = player_position()
	if not ducts.is_empty():
		var pick: Vector2i = ducts[randi() % ducts.size()]
		return Game.data.cell_center(pick, 0.05)
	var best: Vector3 = global_position
	var best_distance: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(&"tanks"):
		var tank: Node3D = node as Node3D
		var d: float = tank.global_position.distance_to(from)
		if d > best_distance:
			best_distance = d
			best = tank.global_position
	return best


## Flat and quick, keeping out of your way until it has worked round to you.
func _run_as_liquid(wd: float) -> void:
	desired_velocity = Vector3.ZERO
	_patience -= wd
	var p: Player = get_player()
	if p == null or not p.alive:
		return
	var to_player: float = flat_distance_to(p.global_position)
	if _patience > 0.0 or to_player > T.beast_rise_distance * 3.0:
		# Working its way to somewhere near you, by way of the ducts if there are any.
		if _went_under.distance_to(global_position) < 0.4 or randf() < 0.01:
			_went_under = _somewhere_to_hide()
		_seep_toward(_went_under, wd)
		return
	_seep_toward(p.global_position, wd)
	# Close enough, and it can see you: it pours up out of the floor behind you.
	if to_player <= T.beast_rise_distance and can_see_player:
		Sfx.play(&"splash", global_position)
		if p.fx != null:
			p.fx.shake(0.05)
		_become(Form.RISING)


func hurt(amount: int, at: Vector3, push: Vector3) -> void:
	if not alive or liquid():
		return
	hp_left -= amount
	Shatter.burst(Game.entities_root(self), at, 5, Mats.specimen(), Vector3.ONE * 0.12, Vector3.UP, 0.13)
	Sfx.play(&"punch", global_position)
	alerted = true
	if hp_left <= 0:
		die(at, push)
		return
	# Hurt it enough in one standing and it gives up the shape, collapses, and comes back from
	# somewhere else. Counted per standing, not against its total, or the first round would do.
	_hits_this_form += 1
	if form == Form.SOLID and _hits_this_form >= T.beast_hits_before_it_melts:
		Sfx.play(&"splash", global_position)
		_charging = -1.0
		_went_under = _somewhere_to_hide()
		_become(Form.SINKING)


func on_bullet_hit(bullet: Node, point: Vector3, _normal: Vector3) -> bool:
	if liquid():
		return false      # a round goes straight through a puddle
	hurt(1, point, (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO)
	return false


func on_laser(direction: Vector3) -> void:
	hurt(4, global_position + Vector3.UP * 1.8, direction)


func on_explosion(centre: Vector3) -> void:
	hurt(5, global_position + Vector3.UP * 1.8, global_position - centre)


func on_stabbed(direction: Vector3) -> void:
	hurt(2, global_position + Vector3.UP * 1.6, direction)


func on_rammed(direction: Vector3) -> void:
	hurt(3, global_position + Vector3.UP * 1.6, direction)


func _take_blunt(_damage: int, _stun_time: float, _push: Vector3) -> void:
	Sfx.play(&"punch", global_position)


func display_name() -> String:
	return "WHATEVER THAT WAS"
