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

const T: Tuning = preload("res://data/tuning.tres")
const DOOR_WIDTH: float = 1.2
const DOOR_HEIGHT: float = 2.2
const FRONT_Z: float = -0.94

var mode: Mode = Mode.EXIT
var phase: Phase = Phase.LOCKED
var door_open: float = 0.0
var button: ElevatorButton

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
		Game.floor_cleared.connect(_on_floor_cleared)
		Game.enemy_killed.connect(func(_left: int) -> void: _refresh_screens())
		if Game.state == Game.State.CLEARED:
			_on_floor_cleared()
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
static func build_shell(parent: Node3D, xform: Transform3D) -> void:
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
	_visual_box(Vector3(1.0, 0.03, 1.0), Vector3(0, 2.46, 0), Mats.accent())                 # light panel
	_visual_box(Vector3(1.7, 0.05, 0.05), Vector3(0, 1.0, 0.86), Mats.steel())               # handrail
	for x: float in [-0.6, 0.0, 0.6]:                                                        # wall panel seams
		_visual_box(Vector3(0.015, 2.3, 0.01), Vector3(x, 1.25, 0.895), Mats.locked())

	# The frame: steel trim around the opening, standing proud of the wall.
	var trim: Material = Mats.gunmetal()
	_visual_box(Vector3(0.09, DOOR_HEIGHT + 0.09, 0.10), Vector3(-(DOOR_WIDTH * 0.5 + 0.045), (DOOR_HEIGHT + 0.09) * 0.5, FRONT_Z - 0.06), trim)
	_visual_box(Vector3(0.09, DOOR_HEIGHT + 0.09, 0.10), Vector3(DOOR_WIDTH * 0.5 + 0.045, (DOOR_HEIGHT + 0.09) * 0.5, FRONT_Z - 0.06), trim)
	_visual_box(Vector3(DOOR_WIDTH + 0.18, 0.09, 0.10), Vector3(0, DOOR_HEIGHT + 0.045, FRONT_Z - 0.06), trim)
	_visual_box(Vector3(DOOR_WIDTH, 0.02, 0.16), Vector3(0, 0.01, FRONT_Z), Mats.steel())   # sill

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.2, 0)
	lamp.omni_range = 3.2
	lamp.light_energy = 0.7
	lamp.light_color = Color(0.8, 0.95, 1.0)
	lamp.shadow_enabled = false
	add_child(lamp)


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

func _on_floor_cleared() -> void:
	if phase == Phase.LOCKED:
		phase = Phase.READY
		Sfx.play(&"ding", global_position)
		_refresh_screens()


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
				_timer = _seconds(T.elevator_ride_seconds)
				Sfx.play_music()
				ride_started.emit()
				_refresh_screens()
		Phase.RIDING:
			_timer -= delta
			_refresh_screens()
			if _timer <= 0.0:
				phase = Phase.DONE
				Game.next_floor.call_deferred()
		Phase.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.OPENING
				Sfx.play(&"ding", global_position)
				Sfx.stop_music(2.5)
	_apply_doors()
	button.set_lit(phase == Phase.READY and mode == Mode.EXIT and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6)


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
