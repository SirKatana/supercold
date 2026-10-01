class_name Shelving
extends StaticBody3D
## A run of shelves that can be brought down. Shoot it, punch it, bash it with the ram or set
## off a barrel next to it and the whole thing goes over: what was on it comes off, the pot
## plants break on the floor, and anybody standing under it ends up with a broken leg.
##
## What is left is a waist-high heap, which is still cover. Nothing about it kills.

signal collapsed

const T: Tuning = preload("res://data/tuning.tres")

## What was on these shelves, which decides what falls off them.
var stock: StringName = &"books"
## How long the run is, in cells.
var cells: int = 1

var hp: int = 3
var down: bool = false

var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group(&"shelving")
	add_to_group(&"breakables")
	collision_layer = 1 | 32      # world, and something a punch or a bullet can find
	collision_mask = 0
	for child: Node in get_children():
		if child is CollisionShape3D:
			_shape = child


func on_punched(by: Node, _at: Vector3) -> void:
	var from: Vector3 = (by as Node3D).global_position if by is Node3D else global_position
	take_damage(1, (global_position - from).normalized())


func on_thrown_hit(item: Pickup) -> void:
	take_damage(2, item.velocity.normalized())


## Bullets chip it but a single round does not bring a bay of shelving down.
func on_bullet_hit(bullet: Node, point: Vector3, normal: Vector3) -> bool:
	Shatter.burst(Game.entities_root(self), point + normal * 0.04, 3, Mats.wood(),
		Vector3.ONE * 0.025, normal * 1.6, 0.04)
	take_damage(1, (bullet as Bullet).direction if bullet is Bullet else Vector3.FORWARD)
	return false


## The ram and explosions take the whole thing out at once.
func smash(direction: Vector3) -> void:
	take_damage(hp, direction)


func take_damage(amount: int, direction: Vector3) -> void:
	if down:
		return
	hp -= amount
	if hp > 0:
		Sfx.play(&"door_hit", global_position)
		return
	_come_down(direction)


## Over it goes. The stock comes off, the pots break, and whoever is near it is hurt but not
## killed: a broken leg is the point of the thing.
func _come_down(direction: Vector3) -> void:
	down = true
	var away: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if away.length() < 0.05:
		away = Vector3.FORWARD
	away = away.normalized()

	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	# What is left is a heap: still cover, but you can see and shoot over it.
	if _shape != null and _shape.shape is BoxShape3D:
		var box: BoxShape3D = (_shape.shape as BoxShape3D).duplicate()
		var was: float = box.size.y
		box.size.y = T.shelf_heap_height
		_shape.shape = box
		_shape.position.y -= (was - T.shelf_heap_height) * 0.5

	_spill(away)
	_hurt_whoever_is_under_it()
	Sfx.play(&"door_break", global_position)
	collapsed.emit()


## The stock, all over the floor: books, boxes, helmets or buckets depending on the floor.
func _spill(away: Vector3) -> void:
	var length: float = Furniture.shelf_length(cells)
	var how_many: int = clampi(int(length * 5.0), 8, 36)
	var root: Node3D = Game.entities_root(self)
	for i: int in how_many:
		var along: float = (float(i) / maxf(how_many - 1.0, 1.0) - 0.5) * length
		var at: Vector3 = global_position + Vector3(0, randf_range(-0.4, 0.9), 0) \
			+ global_transform.basis.z * along
		var toss: Vector3 = away * randf_range(1.2, 3.4) + Vector3.UP * randf_range(0.6, 2.2)
		# The last argument is the shard's size in metres. Passing the throw strength there
		# filled the room with four-metre slabs of yellow.
		Shatter.burst(root, at, 1, _stock_material(i), _stock_size(), toss, _stock_shard())
	_drop_the_pots(away, length, root)


## Pot plants go over the edge and break where they land.
func _drop_the_pots(away: Vector3, length: float, root: Node3D) -> void:
	var pots: int = clampi(cells, 1, 3)
	for i: int in pots:
		var along: float = (float(i) + 0.5) / float(pots) * length - length * 0.5
		var at: Vector3 = global_position + Vector3(0, 0.75, 0) + global_transform.basis.z * along
		var pot := FallingPot.new()
		pot.name = "FallingPot"
		root.add_child(pot)
		pot.global_position = at
		pot.velocity = away * randf_range(0.8, 1.8) + Vector3.UP * 0.6


func _stock_material(index: int) -> Material:
	match stock:
		&"suits": return Mats.spacesuit() if index % 3 else Mats.hazard_yellow()
		&"cleaning": return Mats.mop_bucket_yellow() if index % 2 else Mats.polymer()
		&"store": return Mats.cardboard()
		_: return Mats.book(index * 7 + 3)


## How far from the shelf a piece may start, and how big each piece is.
func _stock_size() -> Vector3:
	return Vector3(0.10, 0.08, 0.10)


func _stock_shard() -> float:
	match stock:
		&"suits": return 0.13
		&"cleaning": return 0.14
		&"store": return 0.16
		_: return 0.11      # a book


## Anybody caught under a run of shelves comes out of it limping.
func _hurt_whoever_is_under_it() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude == null or not dude.alive:
			continue
		if dude.global_position.distance_to(global_position) > T.shelf_crush_radius + Furniture.shelf_length(cells) * 0.5:
			continue
		dude.break_a_leg()
