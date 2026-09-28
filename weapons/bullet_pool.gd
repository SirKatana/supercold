class_name BulletPool
extends Node3D
## Reuses Bullet nodes. One pool per level, found through the `bullet_pool` group.

var _bullets: Array[Bullet] = []


const PREWARM: int = 72


func _ready() -> void:
	add_to_group(&"bullet_pool")
	# Built at level load so a firefight never allocates.
	for i: int in PREWARM:
		var bullet := Bullet.new()
		add_child(bullet)
		_bullets.append(bullet)


static func for_node(node: Node) -> BulletPool:
	var existing: Node = node.get_tree().get_first_node_in_group(&"bullet_pool")
	if existing != null and not existing.is_queued_for_deletion():
		return existing as BulletPool
	var pool := BulletPool.new()
	pool.name = "BulletPool"
	Game.entities_root(node).add_child(pool)
	return pool


func fire(from: Vector3, direction: Vector3, shooter: Node, size: float = 1.0, pierce: int = 0,
		speed: float = 1.0, style: StringName = &"") -> Bullet:
	var bullet: Bullet = null
	for b: Bullet in _bullets:
		if not b.active:
			bullet = b
			break
	if bullet == null:
		bullet = Bullet.new()
		add_child(bullet)
		_bullets.append(bullet)
	bullet.set_style(style)
	bullet.launch(from, direction, shooter, size, pierce, speed)
	return bullet


func active_count() -> int:
	var n: int = 0
	for b: Bullet in _bullets:
		if b.active:
			n += 1
	return n
