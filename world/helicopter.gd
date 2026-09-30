class_name Helicopter
extends Node3D
## The way off the roof. It flies in once the Director is dead, lands beside the helipad and
## hangs a ladder out of its door. Climb it and the pilot tells you where you are going next.
##
## The airframe is built hollow: a floor, a roof, two side walls, a glazed nose and an open
## left doorway, so the seats and the man in them are visible from outside. Four things move
## on their own nodes -- the main rotor, the tail rotor, the sliding door and the engine
## cowling -- and everything under that cowling (block, gearbox, looms, hoses) is modelled,
## because the hatch really opens.
##
## No collision anywhere: like the chandelier, it must never block a shot or a step. It runs on
## real time, not world time, because it is a cutscene and not part of the fight.

signal landed
signal boarded

const T: Tuning = preload("res://data/tuning.tres")

## Where it sits relative to the pad: beside it, door and ladder facing the pad.
const PARKED := Vector3(3.1, 0.0, 0.0)
const APPROACH := Vector3(-34.0, 21.0, -46.0)
const FLY_IN_SECONDS: float = 6.5
const CLIMB_SECONDS: float = 2.6
const LINE_SECONDS: float = 3.4
const LIFT_SPEED: float = 3.2
## How far the door runs back, and how far the cowling tips up off the deck.
const DOOR_TRAVEL: float = 1.45
const COWLING_ANGLE: float = -1.05

var has_landed: bool = false
var taking_off: bool = false

var _rotor: Node3D
var _tail_rotor: Node3D
var _door: Node3D
var _cowling: Node3D
var _bubble: Label3D
var _pad_position: Vector3
var _carried: Player = null


func _ready() -> void:
	add_to_group(&"helicopter")
	_add_part(self, &"helicopter", _model)
	_add_part(self, &"helicopter_engine", _model_engine)
	_add_part(self, &"helicopter_cabin", _model_cabin)

	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 2.92, 0.15)
	add_child(_rotor)
	_add_part(_rotor, &"helicopter_rotor", _model_rotor)

	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.24, 2.62, 5.72)
	add_child(_tail_rotor)
	_add_part(_tail_rotor, &"helicopter_tail_rotor", _model_tail_rotor)

	# The door slides back along its rail; closed it fills the opening.
	_door = Node3D.new()
	_door.position = Vector3(-1.14, 0.0, 0.0)
	add_child(_door)
	_add_part(_door, &"helicopter_door", _model_door)

	# The cowling is hinged along its front edge, so it tips up and forward off the deck.
	_cowling = Node3D.new()
	_cowling.position = Vector3(0, 2.30, 0.92)
	add_child(_cowling)
	_add_part(_cowling, &"helicopter_cowling", _model_cowling)

	_bubble = Label3D.new()
	_bubble.text = ""
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 96
	_bubble.pixel_size = 0.0022
	_bubble.outline_size = 26
	_bubble.modulate = Color(1, 1, 1)
	_bubble.outline_modulate = Color(0.02, 0.02, 0.04)
	_bubble.position = Vector3(-0.2, 3.1, -1.1)
	_bubble.visible = false
	add_child(_bubble)


func _add_part(parent: Node3D, key: StringName, build: Callable) -> void:
	var part := MeshInstance3D.new()
	part.mesh = MeshKit.cached(key, build)
	parent.add_child(part)


## Called by the pad the moment the floor is clear. `at` is the pad's own position.
func fly_in(at: Vector3) -> void:
	_pad_position = at
	global_position = at + PARKED + APPROACH
	rotation.y = deg_to_rad(38.0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, ^"global_position", at + PARKED, FLY_IN_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, ^"rotation:y", 0.0, FLY_IN_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_touch_down)


func _touch_down() -> void:
	has_landed = true
	Sfx.play(&"slam", global_position)
	open_up()
	landed.emit()


## Down on the skids: the door runs back and the engine hatch comes up, the way a machine
## looks while it is waiting with the rotor still turning.
func open_up() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_door, ^"position:z", DOOR_TRAVEL, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_cowling, ^"rotation:x", COWLING_ANGLE, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close_up() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_door, ^"position:z", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_cowling, ^"rotation:x", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


## The player walks onto the pad with the machine sitting there: he climbs in and it leaves.
func board(who: Player) -> void:
	if not has_landed or _carried != null or who == null or not who.alive:
		return
	_carried = who
	who.input_enabled = false
	who.riding = true
	who.velocity = Vector3.ZERO
	var ladder_foot: Vector3 = global_position + Vector3(-1.75, 0.0, 0.3)
	var cabin: Vector3 = global_position + Vector3(-0.35, 0.95, 0.15)
	var tween: Tween = create_tween()
	tween.tween_property(who, ^"global_position", ladder_foot, 0.7).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(who, ^"rotation:y", _facing_from(who, global_position), 0.7)
	tween.tween_property(who, ^"global_position", cabin, CLIMB_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(who.head, ^"rotation:x", deg_to_rad(-6.0), CLIMB_SECONDS)
	tween.tween_callback(_say_the_line)


## Yaw that turns `who` toward `target`, taking the short way round from where he stands.
func _facing_from(who: Node3D, target: Vector3) -> float:
	var flat := Vector3(target.x - who.global_position.x, 0.0, target.z - who.global_position.z)
	if flat.length() < 0.01:
		return who.rotation.y
	var wanted: float = atan2(-flat.x, -flat.z)
	return who.rotation.y + wrapf(wanted - who.rotation.y, -PI, PI)


func _say_the_line() -> void:
	_bubble.text = "NICE.\nNOW WE GO TO THE\nSPACE STATION."
	_bubble.visible = true
	Sfx.play(&"ding", global_position)
	close_up()
	var tween: Tween = create_tween()
	tween.tween_interval(LINE_SECONDS)
	tween.tween_callback(_take_off)


func _take_off() -> void:
	taking_off = true
	var tween: Tween = create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(_finish)


func _finish() -> void:
	if _carried != null and is_instance_valid(_carried):
		_carried.riding = false
	boarded.emit()
	Game.next_floor()


func _process(delta: float) -> void:
	# Real time: the rotors keep turning while the world crawls.
	_rotor.rotation.y = wrapf(_rotor.rotation.y + delta * 26.0, 0.0, TAU)
	_tail_rotor.rotation.x = wrapf(_tail_rotor.rotation.x + delta * 40.0, 0.0, TAU)
	if not taking_off:
		return
	var step: Vector3 = Vector3(0.0, LIFT_SPEED, -LIFT_SPEED * 0.45) * delta
	global_position += step
	if _carried != null and is_instance_valid(_carried):
		_carried.global_position += step


# ---------------------------------------------------------------- the airframe
# -Z is the nose. The cabin floor is at 0.90 and its roof at 2.34; the boom runs back to 6.0.

const FLOOR_Y: float = 0.90
const ROOF_Y: float = 2.34
const HALF_WIDTH: float = 1.10


## Shell, tail, skids and ladder. The cabin fit-out is a separate mesh so the inside can carry
## its own materials without the whole hull turning matte.
static func _model(kit: MeshKit) -> void:
	var shell: Material = Mats.white_paint()
	var dark: Material = Mats.gunmetal()
	var glass: Material = Mats.visor_glass()
	var trim: Material = Mats.hazard_yellow()

	# --- floor pan and roof, each with thickness, so the hull is not a sheet
	kit.box(Vector3(2.24, 0.12, 3.10), Vector3(0, FLOOR_Y - 0.06, -0.30), dark)
	kit.box(Vector3(2.20, 0.10, 3.06), Vector3(0, ROOF_Y + 0.05, -0.30), shell)
	kit.box(Vector3(2.26, 0.09, 2.10), Vector3(0, ROOF_Y - 0.03, -0.30), trim)     # cabin stripe

	# --- right side: a solid panel with a window in it, up to the roof
	kit.box(Vector3(0.09, 1.50, 3.06), Vector3(HALF_WIDTH, 1.62, -0.30), shell)
	kit.box(Vector3(0.11, 0.62, 1.15), Vector3(HALF_WIDTH, 1.86, -0.55), glass)
	# --- left side: only the panel forward of the doorway; the door fills the rest
	kit.box(Vector3(0.09, 1.50, 0.95), Vector3(-HALF_WIDTH, 1.62, -1.32), shell)
	kit.box(Vector3(0.11, 0.55, 0.55), Vector3(-HALF_WIDTH, 1.88, -1.32), glass)
	# Doorway posts and rail, so the opening has a frame round it.
	for post: float in [-0.62, 0.86]:
		kit.box(Vector3(0.13, 1.52, 0.13), Vector3(-HALF_WIDTH, 1.62, post), dark)
	kit.box(Vector3(0.12, 0.10, 1.60), Vector3(-HALF_WIDTH - 0.04, ROOF_Y - 0.10, 0.12), dark)

	# --- nose: a glazed cone, a chin bubble under it and the frame over it
	kit.ball(0.86, Vector3(0, 1.68, -1.78), glass, Vector3(1.12, 0.76, 1.05))
	kit.ball(0.50, Vector3(0, 1.20, -1.52), glass, Vector3(1.30, 0.70, 1.10))         # chin window
	kit.box(Vector3(0.07, 0.90, 1.60), Vector3(0, 1.70, -1.96), dark, Vector3(0.22, 0, 0))
	kit.box(Vector3(1.90, 0.09, 0.60), Vector3(0, 2.26, -1.55), shell)                # brow
	kit.box(Vector3(2.10, 0.30, 0.20), Vector3(0, 0.98, -1.20), dark)                 # nose underside

	# --- engine deck behind the cabin, and the firewall that closes the cabin off
	kit.box(Vector3(2.16, 1.46, 0.10), Vector3(0, 1.60, 1.22), dark)                  # rear bulkhead
	kit.box(Vector3(1.70, 0.12, 1.40), Vector3(0, 2.26, 1.62), dark)                  # engine deck
	kit.box(Vector3(0.14, 0.60, 1.40), Vector3(0.84, 2.58, 1.62), shell)              # deck cheeks
	kit.box(Vector3(0.14, 0.60, 1.40), Vector3(-0.84, 2.58, 1.62), shell)

	# --- tail boom, fin, stabilisers
	kit.tube(0.15, 0.30, 4.20, Vector3(0, 2.10, 4.00), dark, true, 12)
	kit.box(Vector3(0.12, 1.30, 1.05), Vector3(0, 2.66, 5.62), shell, Vector3(-0.26, 0, 0))
	kit.box(Vector3(0.14, 0.45, 0.60), Vector3(0, 1.72, 5.95), shell, Vector3(-0.50, 0, 0))
	kit.box(Vector3(2.00, 0.09, 0.58), Vector3(0, 2.14, 5.05), shell)
	kit.box(Vector3(0.20, 0.42, 0.30), Vector3(0.30, 2.62, 5.62), dark)               # tail gearbox

	# --- skids: rails, cross tubes, struts and a step
	for side: float in [-1.0, 1.0]:
		kit.tube(0.062, 0.062, 3.40, Vector3(side * 1.14, 0.13, -0.30), dark, true, 8)
		kit.tube(0.062, 0.062, 0.34, Vector3(side * 1.14, 0.22, -2.02), dark, true, 8,
			Vector3(0.9, 0, 0))                                                      # turned-up toe
	for along: float in [-1.20, 0.80]:
		kit.tube(0.075, 0.075, 2.30, Vector3(0, 0.52, along), dark, true, 8, Vector3(0, 0, PI * 0.5))
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(0.09, 0.62, 0.09), Vector3(side * 0.90, 0.46, along), dark,
				Vector3(0, 0, side * -0.44))
	kit.box(Vector3(0.44, 0.06, 0.60), Vector3(-1.14, 0.56, 0.20), dark)              # step

	# --- the ladder out of the door: rails, rungs and the hooks over the sill
	for rail: float in [-1.0, 1.0]:
		kit.box(Vector3(0.07, 1.10, 0.07), Vector3(-1.52, 0.44, 0.15 + rail * 0.28), dark)
	for rung: int in 4:
		kit.box(Vector3(0.11, 0.05, 0.63), Vector3(-1.52, 0.12 + rung * 0.27, 0.15), dark)
	kit.box(Vector3(0.40, 0.06, 0.63), Vector3(-1.34, 0.96, 0.15), dark)


## What is inside: seats, harnesses, the instrument panel, cyclic and collective sticks, and
## the pilot in the right-hand seat. All of it visible through the open door.
static func _model_cabin(kit: MeshKit) -> void:
	var dark: Material = Mats.gunmetal()
	var seat_cloth: Material = Mats.overalls_dark()
	var screen: Material = Mats.screen_lit()
	var lamp: Material = Mats.lift_light()

	# Instrument panel across the front, canted back, with lit faces.
	kit.box(Vector3(1.70, 0.62, 0.16), Vector3(0, 1.44, -1.22), dark, Vector3(0.30, 0, 0))
	for gauge: int in 3:
		kit.box(Vector3(0.34, 0.24, 0.05), Vector3(-0.46 + gauge * 0.46, 1.50, -1.30), screen,
			Vector3(0.30, 0, 0))
	kit.box(Vector3(1.10, 0.10, 0.34), Vector3(0, 2.22, -1.12), dark)                 # overhead panel
	kit.box(Vector3(0.50, 0.05, 0.14), Vector3(0, 2.17, -1.12), lamp)                 # its lamps

	for side: float in [-1.0, 1.0]:
		var seat := Vector3(side * 0.46, FLOOR_Y, -0.62)
		kit.box(Vector3(0.58, 0.12, 0.56), seat + Vector3(0, 0.36, 0), seat_cloth)    # squab
		kit.box(Vector3(0.58, 0.76, 0.12), seat + Vector3(0, 0.72, 0.28), seat_cloth) # back
		kit.box(Vector3(0.62, 0.10, 0.62), seat + Vector3(0, 0.28, 0), dark)          # frame
		kit.box(Vector3(0.09, 0.62, 0.09), seat + Vector3(0, 0.62, 0.30), dark)
		# Cyclic between the knees, collective outboard of the seat, pedals on the floor.
		kit.tube(0.028, 0.034, 0.46, seat + Vector3(0, 0.55, -0.34), dark, false, 8)
		kit.tube(0.028, 0.034, 0.40, seat + Vector3(side * 0.32, 0.48, 0.10), dark, false, 8,
			Vector3(0.35, 0, 0))
		kit.box(Vector3(0.36, 0.06, 0.18), seat + Vector3(0, 0.10, -0.78), dark, Vector3(0.35, 0, 0))
	# Rear bench for whoever is riding along.
	kit.box(Vector3(1.90, 0.14, 0.52), Vector3(0, FLOOR_Y + 0.38, 0.86), seat_cloth)
	kit.box(Vector3(1.90, 0.64, 0.12), Vector3(0, FLOOR_Y + 0.70, 1.10), seat_cloth)
	_model_pilot(kit)


## The man in the right-hand seat: flight suit, helmet, dark visor, mic boom, hands on the
## controls. He is the one who tells you about the space station.
static func _model_pilot(kit: MeshKit) -> void:
	var suit: Material = Mats.overalls_dark()
	var helmet: Material = Mats.white_paint()
	var visor: Material = Mats.visor_glass()
	var glove: Material = Mats.black()
	var strap: Material = Mats.hazard_yellow()
	var seat := Vector3(0.46, FLOOR_Y, -0.62)

	kit.box(Vector3(0.52, 0.64, 0.36), seat + Vector3(0, 0.78, -0.04), suit)          # torso
	kit.ball(0.17, seat + Vector3(0, 1.08, -0.02), suit, Vector3(1.0, 0.6, 1.0))      # shoulders
	kit.box(Vector3(0.09, 0.50, 0.09), seat + Vector3(0.14, 0.80, -0.20), strap)      # harness
	kit.box(Vector3(0.09, 0.50, 0.09), seat + Vector3(-0.14, 0.80, -0.20), strap)
	kit.box(Vector3(0.46, 0.20, 0.56), seat + Vector3(0, 0.50, -0.36), suit)          # thighs
	kit.box(Vector3(0.18, 0.46, 0.16), seat + Vector3(0.14, 0.26, -0.62), suit)       # shins
	kit.box(Vector3(0.18, 0.46, 0.16), seat + Vector3(-0.14, 0.26, -0.62), suit)
	kit.box(Vector3(0.20, 0.09, 0.28), seat + Vector3(0.14, 0.07, -0.76), glove)      # boots
	kit.box(Vector3(0.20, 0.09, 0.28), seat + Vector3(-0.14, 0.07, -0.76), glove)

	kit.ball(0.20, seat + Vector3(0, 1.30, -0.04), helmet)                            # helmet
	kit.ball(0.185, seat + Vector3(0, 1.28, -0.14), visor, Vector3(1.0, 0.66, 0.88))  # visor
	kit.box(Vector3(0.10, 0.15, 0.10), seat + Vector3(0.20, 1.26, 0.0), helmet)       # ear cups
	kit.box(Vector3(0.10, 0.15, 0.10), seat + Vector3(-0.20, 1.26, 0.0), helmet)
	kit.tube(0.018, 0.018, 0.24, seat + Vector3(-0.16, 1.16, -0.16), glove, false, 6,
		Vector3(0, 0, -0.9))                                                          # mic boom
	kit.box(Vector3(0.07, 0.05, 0.07), seat + Vector3(-0.06, 1.12, -0.22), glove)     # the mic
	# Arms: one hand down on the cyclic, one out on the collective.
	kit.box(Vector3(0.13, 0.13, 0.42), seat + Vector3(-0.22, 0.80, -0.26), suit, Vector3(0.55, 0, 0))
	kit.box(Vector3(0.12, 0.12, 0.13), seat + Vector3(-0.22, 0.62, -0.40), glove)
	kit.box(Vector3(0.13, 0.13, 0.38), seat + Vector3(0.30, 0.78, -0.02), suit, Vector3(-0.35, 0, 0))
	kit.box(Vector3(0.12, 0.12, 0.13), seat + Vector3(0.32, 0.62, 0.12), glove)


## Under the cowling: engine block, gearbox, exhaust, and the looms and hoses that make it
## read as a machine rather than a box. Drawn whether the hatch is open or shut.
static func _model_engine(kit: MeshKit) -> void:
	var dark: Material = Mats.gunmetal()
	var steel: Material = Mats.steel()
	var hose: Material = Mats.rubber()
	var red: Material = Mats.barrel_red()
	var yellow: Material = Mats.hazard_yellow()
	var green: Material = Mats.leaf_green()
	var deck := Vector3(0, 2.32, 1.62)

	kit.box(Vector3(0.92, 0.52, 1.10), deck + Vector3(0, 0.28, 0.10), dark)           # engine block
	kit.tube(0.26, 0.30, 0.60, deck + Vector3(0, 0.30, -0.52), steel, true, 10)       # compressor
	kit.ball(0.34, deck + Vector3(0, 0.34, -0.72), steel, Vector3(1.0, 0.9, 0.7))     # gearbox
	kit.tube(0.12, 0.14, 0.90, deck + Vector3(0.62, 0.42, 0.34), steel, true, 8,
		Vector3(0, -0.7, 0))                                                          # exhaust stack
	kit.tube(0.16, 0.16, 0.10, deck + Vector3(0.90, 0.42, 0.60), dark, true, 8, Vector3(0, -0.7, 0))
	# Mast from the gearbox up to the rotor head, with its stays.
	kit.tube(0.12, 0.16, 0.66, Vector3(0, 2.86, 0.15), steel, false, 10)
	kit.ball(0.24, Vector3(0, 2.56, 0.15), dark, Vector3(1.0, 0.8, 1.0))
	for stay: int in 4:
		var about: float = TAU * stay / 4.0 + 0.4
		kit.box(Vector3(0.05, 0.60, 0.05), Vector3(sin(about) * 0.26, 2.62, 0.15 + cos(about) * 0.26),
			steel, Vector3(sin(about) * 0.4, 0, cos(about) * -0.4))
	# Looms: bundles of coloured wire running forward off the block, and two fat hoses.
	for wire: int in 7:
		var across: float = -0.34 + wire * 0.11
		var colour: Material = [red, yellow, green, hose][wire % 4]
		kit.box(Vector3(0.035, 0.035, 0.86), deck + Vector3(across, 0.52 + sin(wire) * 0.03, -0.18),
			colour, Vector3(0.22 + wire * 0.02, 0.04 * wire, 0))
		kit.box(Vector3(0.035, 0.30, 0.035), deck + Vector3(across, 0.34, -0.60), colour,
			Vector3(0.5, 0, 0))
	kit.tube(0.055, 0.055, 0.80, deck + Vector3(-0.44, 0.36, 0.06), hose, true, 6, Vector3(0.3, 0, 0))
	kit.tube(0.055, 0.055, 0.70, deck + Vector3(0.44, 0.30, 0.10), hose, true, 6, Vector3(-0.3, 0.2, 0))
	kit.box(Vector3(0.24, 0.20, 0.16), deck + Vector3(-0.44, 0.62, -0.34), yellow)    # junction box


## The hinged hatch over that engine. Its own node pivots along the front edge, so the mesh is
## modelled hanging back from the hinge at the origin.
static func _model_cowling(kit: MeshKit) -> void:
	var shell: Material = Mats.white_paint()
	var dark: Material = Mats.gunmetal()
	kit.box(Vector3(1.66, 0.10, 1.50), Vector3(0, 0.34, 0.74), shell, Vector3(-0.10, 0, 0))
	kit.box(Vector3(1.66, 0.42, 0.10), Vector3(0, 0.16, 1.46), shell)                 # its back face
	kit.box(Vector3(0.10, 0.40, 1.50), Vector3(0.80, 0.16, 0.74), shell)              # cheeks
	kit.box(Vector3(0.10, 0.40, 1.50), Vector3(-0.80, 0.16, 0.74), shell)
	kit.box(Vector3(0.50, 0.05, 0.20), Vector3(0, 0.40, 1.34), dark)                  # handle
	for louvre: int in 3:
		kit.box(Vector3(0.90, 0.04, 0.10), Vector3(0, 0.40, 0.42 + louvre * 0.22), dark)


static func _model_door(kit: MeshKit) -> void:
	var shell: Material = Mats.white_paint()
	var dark: Material = Mats.gunmetal()
	var glass: Material = Mats.visor_glass()
	kit.box(Vector3(0.09, 1.46, 1.44), Vector3(0, 1.62, 0.12), shell)
	kit.box(Vector3(0.11, 0.58, 0.96), Vector3(0, 1.94, 0.12), glass)                 # door window
	kit.box(Vector3(0.12, 0.09, 1.46), Vector3(-0.02, 2.32, 0.12), dark)              # top rail
	kit.box(Vector3(0.12, 0.09, 1.46), Vector3(-0.02, 0.92, 0.12), dark)              # bottom rail
	kit.box(Vector3(0.13, 0.07, 0.34), Vector3(-0.04, 1.52, -0.42), dark)             # handle


static func _model_rotor(kit: MeshKit) -> void:
	var dark: Material = Mats.gunmetal()
	var steel: Material = Mats.steel()
	kit.tube(0.20, 0.22, 0.26, Vector3.ZERO, steel, false, 10)                        # head
	kit.ball(0.16, Vector3(0, 0.14, 0), dark)
	for blade: int in 4:
		var lean: float = TAU * blade / 4.0
		var out := Vector3(sin(lean), 0.0, cos(lean))
		# Grip at the root, then the blade itself, drooping a little as a parked one does.
		kit.box(Vector3(0.14, 0.14, 0.40), out * 0.34, steel, Vector3(0, lean, 0))
		kit.box(Vector3(0.36, 0.09, 6.40), out * 3.40 + Vector3(0, -0.12, 0), dark,
			Vector3(0, lean, 0.05))
		kit.box(Vector3(0.10, 0.05, 6.00), out * 3.30 + Vector3(0, -0.15, 0), steel,
			Vector3(0, lean, 0.05))                                                   # spar line


static func _model_tail_rotor(kit: MeshKit) -> void:
	var dark: Material = Mats.gunmetal()
	var steel: Material = Mats.steel()
	kit.tube(0.10, 0.10, 0.16, Vector3.ZERO, steel, true, 8, Vector3(0, PI * 0.5, 0))
	for blade: int in 2:
		var lean: float = PI * blade
		kit.box(Vector3(0.05, 1.00, 0.20), Vector3(0.0, cos(lean) * 0.52, sin(lean) * 0.52), dark,
			Vector3(lean, 0, 0))
