class_name Gentleman
extends PinkDude
## Grey from his hat to his shoes, and about a century out of place: a tall stovepipe hat, a
## suit, little round spectacles and a moustache, with a blunderbuss from the 1800s.
##
## He is in no hurry. He takes his time over a shot, and when it goes off it very nearly takes
## him off his feet: the recoil throws him back a pace and his footing goes to pieces for a
## moment, which is when you kill him.

var _hat: MeshInstance3D
var _face: MeshInstance3D
var _suit: MeshInstance3D
var _shoes: Array[MeshInstance3D] = []
var _cuffs: Array[MeshInstance3D] = []
var _recoil: float = 0.0
var _shove: Vector3 = Vector3.ZERO


func _ready() -> void:
	armed_at_spawn = true
	weapon_kind = &"blunderbuss"
	body_material = Mats.gentleman_grey()
	super()
	seeks_weapons = false
	skin.set_sunglasses(false)
	# Dressed head to foot: coat sleeves, trousers, and only his face and hands left grey.
	skin.set_group_material(&"head", Mats.gentleman_skin())
	skin.set_group_material(&"arms", Mats.gentleman_coat())
	skin.set_group_material(&"torso", Mats.gentleman_coat())
	skin.set_group_material(&"legs", Mats.gentleman_trousers())
	_shoes = [_accessory(MeshKit.cached(&"gentleman_shoe", _model_shoe)),
		_accessory(MeshKit.cached(&"gentleman_shoe", _model_shoe))]
	_cuffs = [_accessory(MeshKit.cached(&"gentleman_cuff", _model_cuff)),
		_accessory(MeshKit.cached(&"gentleman_cuff", _model_cuff))]
	_hat = _accessory(MeshKit.cached(&"gentleman_hat", _model_hat))
	_face = _accessory(MeshKit.cached(&"gentleman_face", _model_face))
	_suit = _accessory(MeshKit.cached(&"gentleman_suit", _model_suit))


func voice_name_id() -> StringName:
	return &"name_gentleman"


func wears_shades() -> bool:
	return false      # he has his own spectacles, thank you


func seeks_cover() -> bool:
	return true


func move_speed() -> float:
	return T.gentleman_speed


func _accessory(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A stovepipe hat: tall crown, flat top, curled brim, and a band. Origin at the skull, -Z forward.
static func _model_hat(kit: MeshKit) -> void:
	var felt: Material = Mats.gentleman_hat()
	kit.tube(0.118, 0.126, 0.300, Vector3(0, 0.255, 0.004), felt, false, 18)      # crown
	kit.tube(0.122, 0.122, 0.018, Vector3(0, 0.405, 0.004), felt, false, 18)      # flat top
	kit.tube(0.205, 0.205, 0.022, Vector3(0, 0.108, 0.004), felt, false, 20)      # brim
	kit.tube(0.185, 0.205, 0.016, Vector3(0, 0.124, 0.004), felt, false, 20)      # its curl
	kit.tube(0.130, 0.130, 0.040, Vector3(0, 0.132, 0.004), Mats.polymer(), false, 18)   # band
	kit.box(Vector3(0.030, 0.026, 0.010), Vector3(0.06, 0.132, -0.118), Mats.brass())    # buckle


## Round spectacles on a wire, and a full moustache.
static func _model_face(kit: MeshKit) -> void:
	var wire: Material = Mats.brass()
	var hair: Material = Mats.gentleman_hair()
	for side: float in [-1.0, 1.0]:
		kit.tube(0.040, 0.040, 0.006, Vector3(0.044 * side, 0.028, -0.104), wire, true, 14)   # rim
		kit.tube(0.034, 0.034, 0.004, Vector3(0.044 * side, 0.028, -0.106), Mats.glass(), true, 14)
		kit.box(Vector3(0.010, 0.006, 0.075), Vector3(0.078 * side, 0.030, -0.060), wire)      # arm to the ear
	kit.box(Vector3(0.026, 0.005, 0.006), Vector3(0, 0.028, -0.108), wire)                     # bridge
	# Moustache: a heavy bar under the nose, with the ends waxed and turned up.
	kit.box(Vector3(0.092, 0.030, 0.026), Vector3(0, -0.026, -0.098), hair)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.046, 0.026, 0.024), Vector3(0.060 * side, -0.018, -0.096), hair, Vector3(0, 0, -0.55 * side))
		kit.box(Vector3(0.024, 0.034, 0.022), Vector3(0.082 * side, 0.004, -0.092), hair, Vector3(0, 0, -1.0 * side))
	kit.box(Vector3(0.030, 0.020, 0.020), Vector3(0, -0.062, -0.094), hair)      # a tuft below the lip


## The coat, worn over everything: a rounded body rather than a slab, shoulders, lapels,
## a waistcoat with buttons, a wing collar and cravat, and tails hanging behind.
static func _model_suit(kit: MeshKit) -> void:
	var coat: Material = Mats.gentleman_coat()
	var linen: Material = Mats.gentleman_linen()
	var waistcoat: Material = Mats.gentleman_waistcoat()
	var brass: Material = Mats.brass()
	kit.tube(0.185, 0.165, 0.46, Vector3(0, 0.010, 0), coat, false, 16)                   # body of the coat
	kit.tube(0.150, 0.185, 0.10, Vector3(0, 0.235, 0), coat, false, 16)
	for side: float in [-1.0, 1.0]:
		kit.ball(0.090, Vector3(0.150 * side, 0.205, 0), coat, Vector3(1.0, 0.85, 1.0))   # shoulder
		kit.tube(0.075, 0.085, 0.10, Vector3(0.150 * side, 0.145, 0), coat, false, 12)    # sleeve head
	kit.tube(0.120, 0.112, 0.34, Vector3(0, 0.020, -0.045), waistcoat, false, 14)
	kit.box(Vector3(0.105, 0.250, 0.030), Vector3(0, 0.055, -0.150), linen)               # shirt front
	for i: int in 4:
		kit.tube(0.009, 0.009, 0.008, Vector3(0, 0.110 - i * 0.060, -0.163), brass, true, 8)
	for side: float in [-1.0, 1.0]:
		kit.tube(0.030, 0.045, 0.26, Vector3(0.070 * side, 0.090, -0.150), coat, false, 10, Vector3(0.10, 0, 0.30 * side))
		kit.tube(0.028, 0.040, 0.10, Vector3(0.105 * side, 0.205, -0.120), coat, false, 10, Vector3(0.5, 0, 0.7 * side))
	kit.tube(0.078, 0.086, 0.075, Vector3(0, 0.275, -0.010), linen, false, 14)            # wing collar
	kit.ball(0.050, Vector3(0, 0.250, -0.080), waistcoat, Vector3(1.2, 0.9, 0.8))         # cravat knot
	kit.tube(0.030, 0.018, 0.13, Vector3(0, 0.180, -0.105), waistcoat, false, 10, Vector3(0.25, 0, 0))
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(0.135, 0.42, 0.045), Vector3(0.080 * side, -0.190, 0.135), coat, Vector3(0.06, 0, 0.03 * side))   # tails
	kit.box(Vector3(0.055, 0.035, 0.012), Vector3(0.115, 0.150, -0.140), linen, Vector3(0, 0, 0.3))      # pocket square
	kit.box(Vector3(0.085, 0.010, 0.010), Vector3(-0.090, 0.000, -0.150), brass, Vector3(0, 0, -0.35))   # watch chain


## A shoe: rounded toe, a heel, a white tongue. Origin at the ankle, -Z forward.
static func _model_shoe(kit: MeshKit) -> void:
	var leather: Material = Mats.leather_black()
	kit.tube(0.052, 0.058, 0.115, Vector3(0, -0.035, 0.0), leather, false, 12)
	kit.box(Vector3(0.092, 0.055, 0.170), Vector3(0, -0.075, -0.055), leather)
	kit.ball(0.050, Vector3(0, -0.072, -0.135), leather, Vector3(0.9, 0.55, 1.1))
	kit.box(Vector3(0.078, 0.030, 0.055), Vector3(0, -0.100, 0.030), leather)
	kit.box(Vector3(0.060, 0.012, 0.045), Vector3(0, -0.046, -0.030), Mats.gentleman_linen())


## A white cuff at the wrist, below the coat sleeve.
static func _model_cuff(kit: MeshKit) -> void:
	kit.tube(0.047, 0.050, 0.055, Vector3.ZERO, Mats.gentleman_linen(), false, 12)
	kit.tube(0.008, 0.008, 0.006, Vector3(0.046, 0.0, 0.0), Mats.brass(), true, 8)


func _physics_process(delta: float) -> void:
	super(delta)
	if not alive:
		return
	var wd: float = TimeManager.world_delta(delta)
	if _recoil > 0.0:
		# Driven back a pace by his own gun, and his feet not quite keeping up.
		_recoil = maxf(0.0, _recoil - wd)
		desired_velocity = _shove * (_recoil / T.gentleman_recoil_seconds) * T.gentleman_recoil_push


## His things ride on the body wherever it is posed, which is why this hangs off the animation
## and not the physics step: a model viewer poses him without ever running physics.
func _animate(wd: float) -> void:
	super(wd)
	_place_his_things()


func _place_his_things() -> void:
	if joints.is_empty() or _hat == null or _face == null or _suit == null or _shoes.size() < 2:
		return      # the body is posed once inside `super()`, before his things are made
	_hat.global_transform = skin.shades_transform()
	_face.global_transform = skin.shades_transform()
	var chest: Vector3 = joints[Humanoid.index_of(&"chest")]
	var up: Vector3 = (joints[Humanoid.index_of(&"neck")] - joints[Humanoid.index_of(&"spine")]).normalized()
	var across: Vector3 = (joints[Humanoid.index_of(&"shoulder_r")] - joints[Humanoid.index_of(&"shoulder_l")]).normalized()
	_suit.global_transform = Transform3D(Basis(across, up, across.cross(up).normalized()), chest)
	# Shoes on the feet, cuffs at the wrists, both following the walk.
	for i: int in 2:
		var ankle: Vector3 = joints[Humanoid.index_of(&"ankle_r" if i == 0 else &"ankle_l")]
		var toe: Vector3 = joints[Humanoid.index_of(&"toe_r" if i == 0 else &"toe_l")]
		var forward: Vector3 = (toe - ankle).normalized()
		if forward.length() > 0.5:
			_shoes[i].global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), ankle + Vector3(0, 0.02, 0))
		var wrist: Vector3 = joints[Humanoid.index_of(&"wrist_r" if i == 0 else &"wrist_l")]
		var elbow: Vector3 = joints[Humanoid.index_of(&"elbow_r" if i == 0 else &"elbow_l")]
		var along: Vector3 = (wrist - elbow).normalized()
		var ref: Vector3 = Vector3.UP if absf(along.y) < 0.9 else Vector3.FORWARD
		var x_axis: Vector3 = ref.cross(along).normalized()
		_cuffs[i].global_transform = Transform3D(Basis(x_axis, along, x_axis.cross(along)), wrist.lerp(elbow, 0.22))


## The shot, and what it does to him.
func shoot() -> void:
	super()
	if not alive:
		return
	_recoil = T.gentleman_recoil_seconds
	_shove = global_transform.basis.z      # straight back, away from the muzzle
	Sfx.play(&"slam", global_position)
	# His footing goes: the stagger pose, and no aiming until he has it back.
	stun(T.gentleman_recoil_seconds)
	Shatter.burst(Game.entities_root(self), muzzle(), 9, Mats.smoke_grey(),
		Vector3(0.06, 0.06, 0.06), -global_transform.basis.z * 2.2, 0.11)
