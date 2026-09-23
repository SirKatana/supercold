class_name Gun
extends Pickup
## Anything that fires bullets. Subclasses set the numbers and build the model.
## Cooldown runs on world time, so you must let time pass to fire again.

signal ammo_changed(ammo: int)

var ammo: int = 6
var capacity: int = 6
var cooldown: float = 0.35
var cooldown_left: float = 0.0
var _enemy_held: bool = false
var _player_pellets: int = 1
## Hold the trigger to keep firing.
var automatic: bool = false
## Bullets per trigger pull, and the cone they scatter in.
var pellets: int = 1
var spread_deg: float = 0.0
var bullet_scale: float = 1.0
## Dudes a round passes through, and its speed against a pistol round.
var pierce: int = 0
var bullet_speed_scale: float = 1.0
## Needs the off hand on the fore-end.
var two_handed: bool = false
## Right click looks through a scope instead of throwing the gun. Q still throws it.
var has_scope: bool = false
var muzzle_local: Vector3 = Vector3(0, 0.048, -0.20)
## How far a shot lifts the world clock, and how hard it kicks the camera.
var burst_strength: float = 0.10
var kick: float = 0.05
## Enemies fire this many rounds per attack, this far apart in world seconds.
var enemy_burst: int = 1
var enemy_burst_gap: float = 0.12
var sound: StringName = &"shot"
## A quiet weapon does not bring the floor down on you. The crossbow is the only one.
var silent: bool = false
## Rounds left in it when a dude drops it.
var drop_ammo: int = 4
## Pellets when a dude fires it. Fewer than the player gets, or shotgunners are undodgeable.
var enemy_pellets: int = 1
## Dudes open fire inside this range.
var enemy_range: float = 16.0
## How long a dude holds his aim on you before firing it. A sniper takes his time.
var enemy_aim_time: float = 0.7


func is_weapon() -> bool:
	return true


func carry_state() -> Dictionary:
	return {"kind": kind, "ammo": ammo}


func apply_carry_state(state: Dictionary) -> void:
	ammo = int(state.get("ammo", ammo))


func mesh_key() -> StringName:
	return &""


## Overridden: add every part of the model to the kit. -Z is the muzzle.
func _model(_kit: MeshKit) -> void:
	pass


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(mesh_key(), _model)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - TimeManager.world_delta(delta))
	super(delta)


## Switches between the player's numbers and the gentler ones dudes use.
func set_enemy_held(enemy: bool) -> void:
	_player_pellets = maxi(_player_pellets, pellets) if not _enemy_held else _player_pellets
	_enemy_held = enemy
	pellets = enemy_pellets if enemy else _player_pellets


func can_fire() -> bool:
	return ammo > 0 and cooldown_left <= 0.0


func muzzle_position() -> Vector3:
	return global_transform * muzzle_local


## `spend` is false for enemies, who never run dry.
func fire(origin: Vector3, direction: Vector3, shooter: Node, spend: bool = true) -> bool:
	if not can_fire():
		return false
	if spend:
		ammo -= 1
		ammo_changed.emit(ammo)
	cooldown_left = cooldown
	var pool: BulletPool = BulletPool.for_node(self)
	var cone: float = deg_to_rad(spread_deg)
	for i: int in pellets:
		pool.fire(origin, scatter(direction, cone), shooter, bullet_scale, pierce, bullet_speed_scale)
	Sfx.play(sound, origin)
	if spend and not silent:
		Game.emit_noise(origin, T.dude_hearing)
	return true


## A random direction inside a cone of half-angle `cone` around `direction`.
static func scatter(direction: Vector3, cone: float) -> Vector3:
	if cone <= 0.0:
		return direction
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length() < 0.01:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var up: Vector3 = side.cross(direction).normalized()
	var angle: float = randf() * TAU
	var radius: float = tan(cone) * sqrt(randf())
	return (direction + (side * cos(angle) + up * sin(angle)) * radius).normalized()
