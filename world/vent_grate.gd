class_name VentGrate
extends StaticBody3D
## The louvred grate over the mouth of a duct. Punch it, shoot it, kick it with the ram: it
## clatters out of the frame and the duct is open. Nothing else about it matters.

signal broken(grate: VentGrate)

const T: Tuning = preload("res://data/tuning.tres")

var along_x: bool = true
var hp: int = 2
var is_broken: bool = false

var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group(&"grates")
	collision_layer = 32      # breakables, like a door: bullets and punches find it
	collision_mask = 0
	var size := Vector3(VentDuct.WIDTH, VentDuct.HEIGHT, VentDuct.GRATE_THICKNESS) if along_x \
		else Vector3(VentDuct.GRATE_THICKNESS, VentDuct.HEIGHT, VentDuct.WIDTH)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = VentDuct.HEIGHT * 0.5
	add_child(_shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshKit.cached(&"vent_grate", _model)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position.y = VentDuct.HEIGHT * 0.5
	mesh.rotation.y = 0.0 if along_x else PI * 0.5
	add_child(mesh)


## A louvred panel in a frame, with four screws. Origin at its middle, facing +Z.
static func _model(kit: MeshKit) -> void:
	var steel: Material = Mats.steel()
	var dark: Material = Mats.gunmetal()
	var w: float = VentDuct.WIDTH
	var h: float = VentDuct.HEIGHT
	kit.box(Vector3(w, 0.06, 0.05), Vector3(0, h * 0.5 - 0.03, 0), steel)
	kit.box(Vector3(w, 0.06, 0.05), Vector3(0, -h * 0.5 + 0.03, 0), steel)
	kit.box(Vector3(0.06, h, 0.05), Vector3(-w * 0.5 + 0.03, 0, 0), steel)
	kit.box(Vector3(0.06, h, 0.05), Vector3(w * 0.5 - 0.03, 0, 0), steel)
	var louvres: int = 9
	for i: int in louvres:
		var y: float = -h * 0.42 + h * 0.84 * i / (louvres - 1.0)
		kit.box(Vector3(w - 0.10, 0.045, 0.030), Vector3(0, y, 0), dark, Vector3(-0.45, 0, 0))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			kit.tube(0.016, 0.016, 0.014, Vector3(sx * (w * 0.5 - 0.03), sy * (h * 0.5 - 0.03), 0.022), steel, true, 8)


func on_punched(_by: Node, _at: Vector3) -> void:
	take_damage(1, Vector3.ZERO)


func on_thrown_hit(item: Pickup) -> void:
	take_damage(2, item.velocity.normalized())


func on_bullet_hit(bullet: Node, _point: Vector3, _normal: Vector3) -> bool:
	var dir: Vector3 = (bullet as Bullet).direction if bullet is Bullet else Vector3.ZERO
	take_damage(1, dir)
	return false


func take_damage(amount: int, direction: Vector3) -> void:
	if is_broken:
		return
	hp -= amount
	Sfx.play(&"door_hit", global_position)
	if hp > 0:
		return
	is_broken = true
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	Shatter.burst(Game.entities_root(self), global_position + Vector3(0, VentDuct.HEIGHT * 0.5, 0), 7,
		Mats.steel(), Vector3(0.4, 0.4, 0.05), flat * 4.0 + Vector3.UP, 0.09)
	Sfx.play(&"door_break", global_position)
	broken.emit(self)
	queue_free()
