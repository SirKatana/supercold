class_name Elevator
extends Node3D
## A real lift: cabin, door frame, two sliding panels, a call button, and digital floor
## displays outside and inside. It runs on real time, not world time, because it is the
## breather between floors and nobody should wait sixteen times longer for a door.
##
## EXIT mode: locked until the floor is clear, then the button opens it. Step in, the doors
## close, music plays, the display counts up, and the next floor loads.
## ARRIVAL mode: the player starts inside, the doors open, stepping out announces the level.

signal opened
signal ride_started
signal stepped_out

enum Mode { EXIT, ARRIVAL }
enum Phase { LOCKED, READY, OPENING, OPEN, CLOSING, RIDING, WAITING, DONE }

const ARRIVE_SECONDS: float = 0.7

const T: Tuning = preload("res://data/tuning.tres")
const DOOR_WIDTH: float = 1.2
const DOOR_HEIGHT: float = 2.2
const FRONT_Z: float = -0.94

var mode: Mode = Mode.EXIT
var phase: Phase = Phase.LOCKED
var door_open: float = 0.0
var button: ElevatorButton
## The solid cabin walls LevelBuilder made for this lift. An exit lift switches them on when it arrives.
var shell: Array[StaticBody3D] = []
## An exit lift is not there at all until the floor is clear.
var present: bool = true
var _wrong_way: bool = false
var _shudder: float = 0.0
var _last_groan: float = 0.0
var _rest_y: float = 0.0
var _lamp: OmniLight3D
var _arriving: float = -1.0

var _panels: Array[MeshInstance3D] = []
var _door_body: StaticBody3D
var _door_shape: CollisionShape3D
var _inside: Area3D
var _screen_out: Label3D
var _screen_in: Label3D
var _timer: float = 0.0
var _flash_left: float = 0.0
var _player_inside: bool = false
var _announced: bool = false


func _ready() -> void:
	add_to_group(&"exit" if mode == Mode.EXIT else &"arrival")
	if mode == Mode.EXIT:
		add_to_group(&"elevator")
	_build_cabin()
	_build_doors()
	_build_screens()
	_build_button()
	_build_sensor()

	if mode == Mode.EXIT:
		_set_present(false)
		Game.floor_cleared.connect(_on_floor_cleared)
		Game.enemy_killed.connect(func(_left: int) -> void: _refresh_screens())
		# No check of Game.state here. While a floor is being built the state still belongs to
		# the floor before it, and "cleared" there must not bring this lift in.
	else:
		phase = Phase.WAITING
		_timer = _seconds(0.25 if Game.quick_arrival else 1.1)
		if Game.fast_elevators:
			_timer = 0.0
			door_open = 1.0
	_apply_doors()
	_refresh_screens()


func _seconds(normal: float) -> float:
	return 0.05 if Game.fast_elevators else normal


# ---------------------------------------------------------------- building

## The solid cabin walls, built by LevelBuilder under the navmesh parent so dudes path
## around the cabin. `xform` is the elevator's transform in level space.
static func build_shell(parent: Node3D, xform: Transform3D) -> Array[StaticBody3D]:
	var made: Array[StaticBody3D] = []
	var h: float = T.wall_height
	var jamb: float = (2.0 - DOOR_WIDTH) * 0.5
	var boxes: Array = [
		[Vector3(2.0, h, 0.1), Vector3(0, h * 0.5, 0.95), Mats.prop()],
		[Vector3(0.1, h, 2.0), Vector3(-0.95, h * 0.5, 0), Mats.prop()],
		[Vector3(0.1, h, 2.0), Vector3(0.95, h * 0.5, 0), Mats.prop()],
		[Vector3(jamb, h, 0.12), Vector3(-(DOOR_WIDTH + jamb) * 0.5, h * 0.5, FRONT_Z), Mats.wall()],
		[Vector3(jamb, h, 0.12), Vector3((DOOR_WIDTH + jamb) * 0.5, h * 0.5, FRONT_Z), Mats.wall()],
		[Vector3(DOOR_WIDTH, h - DOOR_HEIGHT, 0.12), Vector3(0, DOOR_HEIGHT + (h - DOOR_HEIGHT) * 0.5, FRONT_Z), Mats.wall()],
	]
	for entry: Array in boxes:
		var body: StaticBody3D = LevelBuilder.make_box(entry[0], entry[2])
		body.name = "ElevatorShell"
		body.transform = xform * Transform3D(Basis.IDENTITY, entry[1])
		parent.add_child(body)
		made.append(body)
	return made


func _visual_box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mi.mesh = mesh
	mi.position = at
	add_child(mi)
	return mi


func _build_cabin() -> void:
	_visual_box(Vector3(1.8, 0.04, 1.8), Vector3(0, 0.02, 0), Mats.polymer())                # cabin floor
	_visual_box(Vector3(1.8, 0.06, 1.8), Vector3(0, 2.5, 0), Mats.wall())                    # cabin ceiling
	_visual_box(Vector3(1.0, 0.03, 1.0), Vector3(0, 2.46, 0), Mats.lift_light())             # light panel
	# Everything that makes the cabin read as a room and not a white screen: wainscot, rails,
	# seams, cornice, a framed ceiling light and a button panel. One merged mesh.
	var trim_mesh := MeshInstance3D.new()
	trim_mesh.mesh = MeshKit.cached(&"lift_cabin_trim", _model_cabin_trim)
	trim_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trim_mesh)
	_visual_box(Vector3(1.7, 0.05, 0.05), Vector3(0, 1.0, 0.86), Mats.steel())               # handrail
	for x: float in [-0.6, 0.0, 0.6]:                                                        # wall panel seams
		_visual_box(Vector3(0.015, 2.3, 0.01), Vector3(x, 1.25, 0.895), Mats.locked())

	# The frame: steel trim around the opening, standing proud of the wall.
	var trim: Material = Mats.gunmetal()
	_visual_box(Vector3(0.09, DOOR_HEIGHT + 0.09, 0.10), Vector3(-(DOOR_WIDTH * 0.5 + 0.045), (DOOR_HEIGHT + 0.09) * 0.5, FRONT_Z - 0.06), trim)
	_visual_box(Vector3(0.09, DOOR_HEIGHT + 0.09, 0.10), Vector3(DOOR_WIDTH * 0.5 + 0.045, (DOOR_HEIGHT + 0.09) * 0.5, FRONT_Z - 0.06), trim)
	_visual_box(Vector3(DOOR_WIDTH + 0.18, 0.09, 0.10), Vector3(0, DOOR_HEIGHT + 0.045, FRONT_Z - 0.06), trim)
	_visual_box(Vector3(DOOR_WIDTH, 0.02, 0.16), Vector3(0, 0.01, FRONT_Z), Mats.steel())   # sill

	_rest_y = position.y
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.2, 0)
	lamp.omni_range = 3.2
	# Gentle, and with no specular. At 0.7 with a highlight, the steel doors threw a white bloom
	# across the view and the white walls burned out to a blank screen.
	#
	# But a cabin has to be lit by its own lamp, not by the floor it is on. At the basement's
	# ambient of 0.16 a lamp of 0.3 left the whole ride pitch black with music playing, which
	# is exactly what it looked like: a bug.
	var ambient: float = 0.55
	if Game.data != null:
		ambient = float(Game.data.theme.get("energy", 0.55))
	lamp.light_energy = clampf(0.3 + (0.5 - ambient) * 1.3, 0.3, 0.92)
	lamp.light_specular = 0.0
	lamp.light_color = Color(0.8, 0.95, 1.0)
	lamp.shadow_enabled = false
	add_child(lamp)
	_lamp = lamp


static func _model_door_detail(kit: MeshKit) -> void:
	var w: float = DOOR_WIDTH * 0.5
	for face: float in [-1.0, 1.0]:
		kit.box(Vector3(w * 0.92, 0.22, 0.004), Vector3(0, -DOOR_HEIGHT * 0.5 + 0.13, 0.027 * face), Mats.gunmetal())   # kick plate
		kit.box(Vector3(w * 0.70, DOOR_HEIGHT * 0.52, 0.003), Vector3(0, 0.14, 0.0265 * face), Mats.gunmetal())        # inset panel
		kit.box(Vector3(w * 0.62, DOOR_HEIGHT * 0.46, 0.003), Vector3(0, 0.14, 0.0285 * face), Mats.steel())


static func _model_cabin_trim(kit: MeshKit) -> void:
	var dark: Material = Mats.gunmetal()
	var seam: Material = Mats.locked()
	var metal: Material = Mats.steel()
	var black: Material = Mats.polymer()
	# Wainscot and kick strip on the back wall and both sides.
	kit.box(Vector3(1.80, 0.95, 0.012), Vector3(0, 0.555, 0.893), dark)
	kit.box(Vector3(1.80, 0.08, 0.016), Vector3(0, 0.08, 0.891), black)
	kit.box(Vector3(1.80, 0.02, 0.020), Vector3(0, 1.04, 0.889), metal)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.012, 0.95, 1.80), Vector3(0.893 * side, 0.555, 0), dark)
		kit.box(Vector3(0.016, 0.08, 1.80), Vector3(0.891 * side, 0.08, 0), black)
		kit.box(Vector3(0.020, 0.02, 1.80), Vector3(0.889 * side, 1.04, 0), metal)
		kit.box(Vector3(0.05, 0.05, 1.50), Vector3(0.84 * side, 1.0, 0.05), metal)           # side handrail
		for z: float in [-0.55, 0.65]:
			kit.box(Vector3(0.06, 0.03, 0.03), Vector3(0.87 * side, 1.0, z), metal)          # its brackets
		for z: float in [-0.3, 0.3]:
			kit.box(Vector3(0.010, 1.36, 0.015), Vector3(0.895 * side, 1.74, z), seam)       # upper panel seams
		kit.box(Vector3(0.02, 0.06, 1.80), Vector3(0.885 * side, 2.44, 0), dark)             # cornice
	kit.box(Vector3(1.80, 0.06, 0.02), Vector3(0, 2.44, 0.885), dark)
	# The ceiling light sits in a frame with two bars across it.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(1.10, 0.04, 0.05), Vector3(0, 2.45, 0.525 * side), dark)
		kit.box(Vector3(0.05, 0.04, 1.10), Vector3(0.525 * side, 2.45, 0), dark)
		kit.box(Vector3(0.02, 0.02, 1.00), Vector3(0.17 * side, 2.44, 0), dark)
	# Button panel inside, right of the doors.
	var panel_z: float = FRONT_Z + 0.075
	kit.box(Vector3(0.20, 0.52, 0.015), Vector3(0.76, 1.28, panel_z), metal)
	kit.box(Vector3(0.14, 0.07, 0.006), Vector3(0.76, 1.48, panel_z + 0.009), black)         # little display
	for row: int in 4:
		for column: int in 2:
			kit.tube(0.016, 0.016, 0.008, Vector3(0.735 + column * 0.05, 1.38 - row * 0.065, panel_z + 0.010), Mats.ceramic(), true, 10)
	kit.tube(0.018, 0.018, 0.010, Vector3(0.76, 1.09, panel_z + 0.011), Mats.icon(2), true, 10)   # alarm


func _build_doors() -> void:
	for side: float in [-1.0, 1.0]:
		var panel: MeshInstance3D = _visual_box(Vector3(DOOR_WIDTH * 0.5, DOOR_HEIGHT, 0.05),
			Vector3(side * DOOR_WIDTH * 0.25, DOOR_HEIGHT * 0.5, FRONT_Z + 0.02), Mats.steel())
		var seam := MeshInstance3D.new()
		var seam_mesh := BoxMesh.new()
		seam_mesh.size = Vector3(0.012, DOOR_HEIGHT * 0.92, 0.055)
		seam_mesh.material = Mats.locked()
		seam.mesh = seam_mesh
		seam.position.x = -side * (DOOR_WIDTH * 0.25 - 0.03)
		panel.add_child(seam)
		# Brushed door leaves have a darker kick plate and an inset panel, inside and out, so a
		# door filling the view is still plainly a door.
		var detail := MeshInstance3D.new()
		detail.mesh = MeshKit.cached(&"lift_door_detail", _model_door_detail)
		panel.add_child(detail)
		_panels.append(panel)
	_door_body = StaticBody3D.new()
	_door_body.collision_layer = 1
	_door_body.collision_mask = 0
	_door_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.08)
	_door_shape.shape = box
	_door_body.add_child(_door_shape)
	_door_body.position = Vector3(0, DOOR_HEIGHT * 0.5, FRONT_Z + 0.02)
	add_child(_door_body)


func _make_screen(at: Vector3, facing_out: bool, width: float) -> Label3D:
	_visual_box(Vector3(width, 0.36, 0.03), at, Mats.polymer())
	var label := Label3D.new()
	label.position = at + Vector3(0, 0, -0.02 if facing_out else 0.02)
	label.rotation.y = PI if facing_out else 0.0
	label.pixel_size = 0.0032
	label.font_size = 40
	label.outline_size = 0
	label.modulate = Mats.ACCENT
	label.shaded = false
	label.line_spacing = -4.0
	add_child(label)
	return label


func _build_screens() -> void:
	_screen_out = _make_screen(Vector3(0, DOOR_HEIGHT + 0.42, FRONT_Z - 0.08), true, 1.1)
	_screen_in = _make_screen(Vector3(0, DOOR_HEIGHT + 0.12, FRONT_Z + 0.09), false, 0.9)


func _build_button() -> void:
	button = ElevatorButton.new()
	button.name = "CallButton"
	# On the wall to the right of the doors as you face them. Facing out is -Z, so right is -X.
	button.position = Vector3(-(DOOR_WIDTH * 0.5 + 0.22), 1.2, FRONT_Z - 0.075)
	add_child(button)
	button.pressed.connect(press)


func _build_sensor() -> void:
	_inside = Area3D.new()
	_inside.collision_layer = 0
	_inside.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 2.0, 1.25)
	shape.shape = box
	shape.position = Vector3(0, 1.0, 0.2)
	_inside.add_child(shape)
	add_child(_inside)
	_inside.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = true)
	_inside.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = false
			_on_player_left())


# ---------------------------------------------------------------- behaviour

## There or not there: drawn, solid, and able to be hit, all together.
func _set_present(on: bool) -> void:
	present = on
	visible = on
	for body: StaticBody3D in shell:
		if is_instance_valid(body):
			body.visible = on
			body.collision_layer = 1 if on else 0
	if _door_body != null:
		_door_body.collision_layer = 1 if on else 0
	if button != null:
		button.collision_layer = 32 if on else 0
	if _inside != null:
		_inside.monitoring = on


## The last enemy is dead: the lift arrives. It rises into place, then waits for its button.
func _on_floor_cleared() -> void:
	if phase != Phase.LOCKED or present:
		return
	_set_present(true)
	_arriving = 0.0
	phase = Phase.READY
	Sfx.play(&"ding", global_position)
	Shatter.burst(Game.entities_root(self), global_position + Vector3.UP * 1.4, 18, Mats.accent(), Vector3(0.9, 1.3, 0.9), Vector3.UP * 1.5, 0.08)
	_refresh_screens()
	# Standing where it lands would leave the player shut inside with the button outside.
	var p: Player = get_tree().get_first_node_in_group(&"player") as Player
	if p != null and p.global_position.distance_to(global_position) < 1.6:
		phase = Phase.OPENING


## The call button was punched, shot, or hit by something thrown.
func press() -> void:
	Sfx.play(&"pickup", global_position)
	match phase:
		Phase.LOCKED:
			_flash_left = 1.2
			Sfx.play(&"door_hit", global_position)
		Phase.READY:
			phase = Phase.OPENING
			Sfx.play(&"ding", global_position)
	_refresh_screens()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_refresh_screens()
	if _arriving >= 0.0:
		# Grows up out of the floor over most of a second.
		_arriving += delta
		var t: float = clampf(_arriving / _seconds(ARRIVE_SECONDS), 0.0, 1.0)
		var rise: float = 1.0 - pow(1.0 - t, 3.0)
		scale = Vector3(1.0, maxf(rise, 0.02), 1.0)
		for body: StaticBody3D in shell:
			if is_instance_valid(body):
				(body.get_child(1) as MeshInstance3D).scale.y = maxf(rise, 0.02)
				(body.get_child(1) as MeshInstance3D).position.y = -(1.0 - rise) * 0.5 * T.wall_height
		if t >= 1.0:
			_arriving = -1.0
	var door_speed: float = delta / _seconds(0.9)
	match phase:
		Phase.OPENING:
			door_open = minf(1.0, door_open + door_speed)
			if door_open >= 1.0:
				phase = Phase.OPEN
				opened.emit()
				_refresh_screens()
		Phase.OPEN:
			if mode == Mode.EXIT and _player_inside:
				_timer += delta
				if _timer >= _seconds(0.5):
					phase = Phase.CLOSING
			else:
				_timer = 0.0
		Phase.CLOSING:
			door_open = maxf(0.0, door_open - door_speed)
			if not _player_inside:
				phase = Phase.OPENING      # they backed out, let them
			elif door_open <= 0.0:
				phase = Phase.RIDING
				# The ride down to the basement takes longer, and it does not go well.
				_wrong_way = Game.next_floor_name() == Game.SECRET_FLOOR
				_timer = _seconds(T.basement_ride_seconds if _wrong_way else T.elevator_ride_seconds)
				Sfx.play_music()
				ride_started.emit()
				_refresh_screens()
		Phase.RIDING:
			_timer -= delta
			if _wrong_way:
				_ride_goes_wrong(delta)
			_refresh_screens()
			if _timer <= 0.0:
				phase = Phase.DONE
				Game.glitch = 0.0
				Game.next_floor.call_deferred()
		Phase.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.OPENING
				Sfx.play(&"ding", global_position)
				Sfx.stop_music(2.5)
	_apply_doors()
	button.set_lit(phase == Phase.READY and mode == Mode.EXIT and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6)


## Something is wrong with this lift. It shakes harder the further down it goes, the cabin
## light fails, the picture tears, and the floor screen stops making sense.
func _ride_goes_wrong(delta: float) -> void:
	var total: float = _seconds(T.basement_ride_seconds)
	var through: float = clampf(1.0 - _timer / total, 0.0, 1.0)
	Game.glitch = clampf((through - 0.12) / 0.55, 0.0, 1.0)
	var p: Player = Game.player
	if p != null and is_instance_valid(p):
		p.fx.shake(0.012 + 0.05 * through)
	_shudder += delta
	position.y = _rest_y + sin(_shudder * 34.0) * 0.035 * through + sin(_shudder * 11.0) * 0.02 * through
	if _lamp != null:
		# The light gives out in bursts, and then for good.
		var flicker: float = 1.0 if fmod(_shudder * 7.0, 1.0) > through * 0.85 else 0.05
		_lamp.light_energy = 0.3 * flicker * (1.0 - through * 0.5)
	if through > 0.3 and _shudder - _last_groan > 0.9:
		_last_groan = _shudder
		Sfx.play(&"door_hit", global_position)


func _on_player_left() -> void:
	if mode == Mode.ARRIVAL and not _announced and door_open > 0.5:
		_announced = true
		stepped_out.emit()
		Game.announce_floor()


func _apply_doors() -> void:
	var slide: float = door_open * (DOOR_WIDTH * 0.5 - 0.02)
	_panels[0].position.x = -DOOR_WIDTH * 0.25 - slide
	_panels[1].position.x = DOOR_WIDTH * 0.25 + slide
	_door_shape.disabled = door_open > 0.2


func _refresh_screens() -> void:
	var here: String = Game.floor_label(Game.level_name)
	if mode == Mode.ARRIVAL:
		_screen_out.text = here
		_screen_in.text = here
		return
	if _wrong_way and phase == Phase.RIDING:
		# The floor readout loses its mind on the way down.
		var mess: String = ["LEVEL 13", "LEVEL 1?", "L?V?L ??", "?? ?? ??", "LEVEL ????", "\u2588\u2588\u2588\u2588"][int(_shudder * 6.0) % 6]
		_screen_in.text = "%s\nGOING DOWN" % mess
		_screen_out.text = mess
		return
	var status: String = ""
	match phase:
		Phase.LOCKED:
			status = "LOCKED" if _flash_left > 0.0 else "%d LEFT" % maxi(Game.alive_enemies, 0)
		Phase.READY:
			status = "HIT THE BUTTON"
		Phase.OPENING, Phase.OPEN, Phase.CLOSING:
			status = "GOING UP"
		_:
			status = "IN USE"
	_screen_out.text = "%s\n%s" % [here, status]
	if phase == Phase.RIDING:
		var total: float = _seconds(T.elevator_ride_seconds)
		var dots: String = ".".repeat(1 + int((1.0 - _timer / total) * 3.0) % 4)
		_screen_in.text = "%s\n%s" % [Game.floor_label(Game.next_floor_name()), "GOING UP" + dots]
	else:
		_screen_in.text = here
