class_name Pistol
extends Pickup
## Six rounds. The cooldown runs on world time, so you must let time pass to fire again.

signal ammo_changed(ammo: int)

var ammo: int = 6
var cooldown_left: float = 0.0


static func create(rounds: int = -1) -> Pistol:
	var p := Pistol.new()
	p.kind = &"pistol"
	p.name = "Pistol"
	p.ammo = T.pistol_ammo if rounds < 0 else rounds
	return p


func _build_mesh(root: Node3D) -> void:
	add_box(root, Vector3(0.05, 0.07, 0.26), Vector3(0, 0.03, -0.05))
	add_box(root, Vector3(0.045, 0.13, 0.06), Vector3(0, -0.06, 0.05))


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - TimeManager.world_delta(delta))
	super(delta)


func can_fire() -> bool:
	return ammo > 0 and cooldown_left <= 0.0


func muzzle_position() -> Vector3:
	return global_transform * Vector3(0, 0.03, -0.2)


## `spend` is false for enemies, who never run dry.
func fire(origin: Vector3, direction: Vector3, shooter: Node, spend: bool = true) -> bool:
	if not can_fire():
		return false
	if spend:
		ammo -= 1
		ammo_changed.emit(ammo)
	cooldown_left = T.pistol_cooldown
	BulletPool.for_node(self).fire(origin, direction, shooter)
	Sfx.play(&"shot", origin)
	return true
