class_name FreezeBomb
extends Pickup
## Throw it. Every dude in the radius is frozen solid for a few seconds, and a frozen dude
## shatters to anything: a bullet, a punch, a thrown mug. Walls block it.

var burst_done: bool = false


static func create() -> FreezeBomb:
	var b := FreezeBomb.new()
	b.kind = &"freeze"
	b.name = "FreezeBomb"
	b.blunt_damage = 0
	b.hold_offset = Vector3(0.0, 0.02, -0.04)
	return b


func is_weapon() -> bool:
	return true


func _build_mesh(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cached(&"freeze_bomb", _model)
	root.add_child(mi)


static func _model(kit: MeshKit) -> void:
	var shell: Material = Mats.steel()
	var glow: Material = Mats.accent()
	var dark: Material = Mats.polymer()
	kit.ball(0.085, Vector3.ZERO, Mats.ice())                                   # frosted core
	for i: int in 3:                                                            # three steel cage rings
		kit.tube(0.090, 0.090, 0.014, Vector3.ZERO, shell, false, 16, Vector3(PI * 0.5 if i == 1 else 0.0, 0, PI * 0.5 if i == 2 else 0.0))
	kit.tube(0.030, 0.030, 0.040, Vector3(0, 0.100, 0), dark, false, 10)        # cap
	kit.tube(0.012, 0.012, 0.030, Vector3(0, 0.130, 0), glow, false, 8)         # glowing plunger
	kit.box(Vector3(0.010, 0.050, 0.004), Vector3(0.026, 0.118, 0), shell, Vector3(0, 0, -0.5))   # safety lever
	for i: int in 6:                                                            # snowflake arms on the front
		kit.box(Vector3(0.006, 0.050, 0.004), Vector3(0, 0, -0.088), glow, Vector3(0, 0, i * PI / 3.0))


## Layer 6 too, so a bullet can set it off where it lies.
func _apply_layer() -> void:
	super()
	if state != State.HELD:
		collision_layer |= 32


func on_bullet_hit(_bullet: Node, _point: Vector3, _normal: Vector3) -> void:
	burst()


func _on_flight_hit(collider: Object, point: Vector3, normal: Vector3) -> void:
	if dangerous:
		global_position = point + normal * 0.1
		burst()
		return
	super(collider, point, normal)


func burst() -> int:
	if burst_done:
		return 0
	burst_done = true
	var frozen: int = FreezeBlast.go(Game.entities_root(self), global_position)
	queue_free()
	return frozen
