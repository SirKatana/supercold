class_name Shield
extends Pickup
## A SWAT ballistic shield: black armour plate with a glass viewport. Bullets that strike it
## stop, and one in three ricochets away. A shield trooper dies only to a bullet through the
## glass. Dropped, it lies on the floor until the player takes it with F and wears it.

signal glass_broken

const WIDTH: float = 0.66
const BOTTOM: float = 0.70
const TOP: float = 1.78
const VISOR_Y: float = 1.62
const VISOR_SIZE := Vector2(0.32, 0.125)

## Tests pin the ricochet roll with this. Below zero means use the tuned chance.
## (Tuning values cannot be changed at runtime: `T.x` through a const preload is folded at compile time.)
static var deflect_chance_override: float = -1.0

var holder_dude: PinkDude = null
var worn: bool = false
var glass_intact: bool = true

var _plate: ShieldPlate
var _visor: ShieldPlate
var _glass: MeshInstance3D


static func create() -> Shield:
	var s := Shield.new()
	s.kind = &"shield"
	s.name = "Shield"
	s.blunt_damage = 0
	return s


func _ready() -> void:
	add_to_group(&"shields")
	super()
	_plate = _make_part(Vector3(WIDTH, TOP - BOTTOM, 0.06), Vector3(0, (TOP + BOTTOM) * 0.5, 0), false)
	# The glass stands a little proud of the plate, so a bullet from the front meets it first.
	_visor = _make_part(Vector3(VISOR_SIZE.x, VISOR_SIZE.y, 0.03), Vector3(0, VISOR_Y, -0.05), true)
	_set_solid(false)


func _make_part(size: Vector3, at: Vector3, visor: bool) -> ShieldPlate:
	var part := ShieldPlate.new()
	part.shield = self
	part.is_visor = visor
	part.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	part.add_child(shape)
	part.position = at
	add_child(part)
	return part


func _set_solid(solid: bool) -> void:
	_plate.collision_layer = 128 if solid else 0
	_visor.collision_layer = 128 if solid and (glass_intact or worn) else 0


func _resize_plate(width: float, shift: float) -> void:
	((_plate.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.x = width
	_plate.position.x = shift


func collider_rids() -> Array[RID]:
	return [_plate.get_rid(), _visor.get_rid()]


## Where hands reach for it. The node origin is at the shield's foot.
func grab_point() -> Vector3:
	return global_transform * Vector3(0, (TOP + BOTTOM) * 0.5, 0)


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"swat_shield", _model)
	root.add_child(mi)
	_glass = MeshInstance3D.new()
	var pane := BoxMesh.new()
	pane.size = Vector3(VISOR_SIZE.x, VISOR_SIZE.y, 0.012)
	pane.material = Mats.visor_glass()
	_glass.mesh = pane
	_glass.position = Vector3(0, VISOR_Y, -0.012)
	root.add_child(_glass)
	var label := Label3D.new()
	label.text = "SWAT"
	label.font_size = 64
	label.pixel_size = 0.0021
	label.modulate = Color(0.95, 0.95, 0.95)
	label.outline_size = 0
	label.shaded = false
	label.position = Vector3(0, 1.30, -0.034)
	label.rotation.y = PI     # reads from the front, which is -Z
	root.add_child(label)


## Front is -Z. Three slats make the gentle curve, the centre one is built around the viewport.
static func _model(kit: MeshKit) -> void:
	var armour: Material = Mats.polymer()
	var trim: Material = Mats.rubber()
	var steel: Material = Mats.steel()
	var pad: Material = Mats.locked()
	var paint: Material = Mats.white_paint()
	var h: float = TOP - BOTTOM
	var mid: float = (TOP + BOTTOM) * 0.5
	var centre_w: float = 0.36
	var side_w: float = (WIDTH - centre_w) * 0.5 + 0.02
	var window_top: float = VISOR_Y + VISOR_SIZE.y * 0.5
	var window_bottom: float = VISOR_Y - VISOR_SIZE.y * 0.5

	# Centre slat, in four pieces around the viewport.
	kit.box(Vector3(centre_w, window_bottom - BOTTOM, 0.028), Vector3(0, (window_bottom + BOTTOM) * 0.5, 0), armour)
	kit.box(Vector3(centre_w, TOP - window_top, 0.028), Vector3(0, (TOP + window_top) * 0.5, 0), armour)
	var strip: float = (centre_w - VISOR_SIZE.x) * 0.5
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(strip, VISOR_SIZE.y, 0.028), Vector3((centre_w - strip) * 0.5 * side, VISOR_Y, 0), armour)
		# Side slats, swept back.
		kit.box(Vector3(side_w, h, 0.028), Vector3((centre_w * 0.5 + side_w * 0.5 - 0.012) * side, mid, 0.017), armour, Vector3(0, -0.24 * side, 0))
		kit.box(Vector3(0.018, h + 0.02, 0.040), Vector3((WIDTH * 0.5 + 0.006) * side, mid, 0.036), trim, Vector3(0, -0.24 * side, 0))   # edge guard
	kit.box(Vector3(WIDTH + 0.01, 0.020, 0.040), Vector3(0, TOP + 0.006, 0.012), trim)
	kit.box(Vector3(WIDTH + 0.01, 0.020, 0.040), Vector3(0, BOTTOM - 0.006, 0.012), trim)

	# Viewport frame and its bolts.
	kit.box(Vector3(VISOR_SIZE.x + 0.05, 0.022, 0.012), Vector3(0, window_top + 0.011, -0.018), steel)
	kit.box(Vector3(VISOR_SIZE.x + 0.05, 0.022, 0.012), Vector3(0, window_bottom - 0.011, -0.018), steel)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.022, VISOR_SIZE.y, 0.012), Vector3((VISOR_SIZE.x * 0.5 + 0.014) * side, VISOR_Y, -0.018), steel)
		for y: float in [window_top + 0.011, window_bottom - 0.011]:
			for x: float in [0.06, 0.16]:
				kit.tube(0.006, 0.006, 0.010, Vector3(x * side, y, -0.026), trim, true, 8)

	# Front details: two white stripes, corner rivets, a lamp bar under the viewport.
	kit.box(Vector3(centre_w - 0.04, 0.016, 0.004), Vector3(0, 1.17, -0.016), paint)
	kit.box(Vector3(centre_w - 0.04, 0.016, 0.004), Vector3(0, 1.43, -0.016), paint)
	kit.box(Vector3(0.20, 0.030, 0.020), Vector3(0, window_bottom - 0.060, -0.022), steel)
	for i: int in 5:
		kit.box(Vector3(0.022, 0.018, 0.006), Vector3(-0.072 + i * 0.036, window_bottom - 0.060, -0.034), paint)
	for side: float in [-1.0, 1.0]:
		for y: float in [BOTTOM + 0.06, mid, TOP - 0.06]:
			kit.tube(0.009, 0.009, 0.010, Vector3(0.145 * side, y, -0.018), steel, true, 8)

	# Back: forearm pad, strap, and the grab handle.
	kit.box(Vector3(0.16, 0.30, 0.030), Vector3(-0.04, 1.20, 0.030), pad)
	kit.box(Vector3(0.20, 0.045, 0.012), Vector3(-0.04, 1.27, 0.070), trim)
	kit.box(Vector3(0.20, 0.045, 0.012), Vector3(-0.04, 1.13, 0.070), trim)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.020, 0.020, 0.075), Vector3(0.14 + 0.07 * side, 1.20, 0.050), steel)
	kit.tube(0.013, 0.013, 0.16, Vector3(0.14, 1.20, 0.088), trim, false, 10, Vector3(0, 0, PI * 0.5))


# ---------------------------------------------------------------- bullets

## One in three, unless a test has pinned it.
static func rolls_deflect() -> bool:
	var chance: float = deflect_chance_override if deflect_chance_override >= 0.0 else T.shield_deflect_chance
	return randf() < chance


## Called by either plate. Returns true if the bullet ricochets instead of stopping.
func bullet_struck(part: ShieldPlate, bullet: Node, point: Vector3, normal: Vector3) -> bool:
	if part.is_visor and holder_dude != null and is_instance_valid(holder_dude) and holder_dude.alive:
		var dir: Vector3 = (bullet as Bullet).direction if bullet is Bullet else -normal
		var holder: PinkDude = holder_dude
		holder.call(&"visor_shot", dir)
		if not is_instance_valid(holder) or not holder.alive:
			break_glass(point, normal)      # thick glass survives until the man behind it does not
		return false
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 4, Mats.steel(), Vector3.ONE * 0.02, normal * 2.0, 0.035)
	if rolls_deflect():
		return true
	Sfx.play(&"door_hit", point)
	return false


func break_glass(point: Vector3, normal: Vector3) -> void:
	if not glass_intact:
		return
	glass_intact = false
	_glass.visible = false
	Shatter.burst(Game.entities_root(self), point, 10, Mats.visor_glass(), Vector3(0.14, 0.05, 0.02), normal * 1.5, 0.05)
	Sfx.play(&"shatter", point)
	glass_broken.emit()


# ---------------------------------------------------------------- who has it

func give_to(dude: PinkDude, anchor: Node3D) -> void:
	holder_dude = dude
	worn = false
	attach_to(anchor)
	_set_solid(true)


## Strapped to the player's left arm, held up in front. `mount` is the player's head.
func wear(mount: Node3D) -> void:
	holder_dude = null
	worn = true
	attach_to(mount)
	# Left of centre and turned in, so the crosshair stays clear and the viewport sits at eye level.
	transform = Transform3D(Basis(Vector3.UP, -0.20), Vector3(-0.37, -VISOR_Y - 0.015, -0.50))
	# The plate you see sits left so the crosshair is clear. The plate that stops bullets
	# is wider and reaches across the chest, or the shield would protect one shoulder.
	_resize_plate(1.05, 0.20)
	_set_solid(true)
	Sfx.play(&"pickup")


## Dropped flat on the floor, face up, where `at` is.
func release_to_floor(at: Vector3) -> void:
	holder_dude = null
	worn = false
	var world: Node = Game.entities_root(self)
	if get_parent() != world:
		reparent(world, false)
	state = State.RESTING
	_resize_plate(WIDTH, 0.0)
	var yaw: float = randf() * TAU
	global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(at.x, 0.06, at.z))
	_apply_layer()
	_set_solid(false)
