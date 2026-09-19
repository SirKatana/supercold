extends "res://tests/test_case.gd"


class Dummy:
	extends StaticBody3D
	var bullet_hits: int = 0
	var thrown_hits: int = 0
	var punches: int = 0

	func on_bullet_hit(_b: Node, _p: Vector3, _n: Vector3) -> void:
		bullet_hits += 1

	func on_thrown_hit(_item: Pickup) -> void:
		thrown_hits += 1

	func on_punched(_by: Node, _at: Vector3) -> void:
		punches += 1


var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	TimeManager.override_scale = 1.0
	await wait_frames(1)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.unload_level()


func _box(size: Vector3, at: Vector3, layer: int = 1) -> Dummy:
	var body := Dummy.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at
	return body


func test_bullet_never_tunnels_thin_wall_at_full_speed() -> void:
	var wall: Dummy = _box(Vector3(4, 4, 0.1), Vector3(0, 0, -6.03))
	await wait_physics(2)
	var pool: BulletPool = BulletPool.for_node(world)
	for i: int in 12:
		# Stagger the start so the 0.5 m per tick steps land differently around the wall.
		var bullet: Bullet = pool.fire(Vector3(0, 0, -i * 0.043), Vector3.FORWARD, null)
		for tick: int in 40:
			if not bullet.active:
				break
			await wait_physics(1)
		check(not bullet.active, "bullet %d should have stopped" % i)
		check(bullet.global_position.z > -6.1, "bullet %d passed the wall (z=%.2f)" % [i, bullet.global_position.z])
	check_eq(wall.bullet_hits, 12, "every bullet hit the wall")
	pool.queue_free()


func test_pistol_ammo_and_empty() -> void:
	var pistol: Pistol = Pistol.create()
	world.add_child(pistol)
	await wait_physics(1)
	var fired: int = 0
	for i: int in 10:
		if pistol.fire(Vector3(0, 50, 0), Vector3.UP, null):
			fired += 1
		pistol.cooldown_left = 0.0
	check_eq(fired, T.pistol_ammo, "fires exactly one magazine")
	check_eq(pistol.ammo, 0, "ammo is zero")
	check(not pistol.can_fire(), "cannot fire when empty")


func test_cooldown_runs_on_world_time() -> void:
	var pistol: Pistol = Pistol.create()
	world.add_child(pistol)
	TimeManager.override_scale = T.min_scale
	await wait_frames(2)
	check(pistol.fire(Vector3(0, 50, 0), Vector3.UP, null), "first shot")
	await wait_physics(int(T.pistol_cooldown * 60.0) + 6)
	check(not pistol.can_fire(), "real time alone must not reset the cooldown while the world crawls")
	TimeManager.override_scale = 1.0
	await wait_physics(int(T.pistol_cooldown * 60.0) + 6)
	check(pistol.can_fire(), "cooldown clears once world time has passed")


func test_thrown_item_blocks_bullet() -> void:
	var item: Throwable = Throwable.create(&"keyboard")
	world.add_child(item)
	item.throw_from(Vector3(0, 0, -3), Vector3.ZERO, null)
	await wait_physics(2)
	var state: Dictionary = {"hit": null}
	var bullet: Bullet = BulletPool.for_node(world).fire(Vector3.ZERO, Vector3.FORWARD, null)
	bullet.hit.connect(func(collider: Object, _point: Vector3) -> void: state["hit"] = collider)
	for tick: int in 30:
		if not bullet.active:
			break
		await wait_physics(1)
	check(state["hit"] == item, "bullet should stop on the flying keyboard")


func test_resting_item_does_not_block_bullet() -> void:
	var item: Throwable = Throwable.create(&"keyboard")
	world.add_child(item)
	item.global_position = Vector3(0, 0, -3)
	await wait_physics(2)
	var bullet: Bullet = BulletPool.for_node(world).fire(Vector3.ZERO, Vector3.FORWARD, null)
	await wait_physics(20)
	check(bullet.active and bullet.global_position.z < -5.0, "bullet flies over a resting item")
	bullet.deactivate()


func test_thrown_item_hits_target_and_lands() -> void:
	var floor_body: Dummy = _box(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	var target: Dummy = _box(Vector3(1, 2, 1), Vector3(0, 1, -5), 4)
	await wait_physics(2)
	var item: Throwable = Throwable.create(&"stapler")
	world.add_child(item)
	item.throw_from(Vector3(0, 1.4, 0), Vector3.FORWARD * T.throw_speed, null)
	await wait_physics(120)
	check_eq(target.thrown_hits, 1, "target was hit once")
	check_eq(item.state, Pickup.State.RESTING, "item comes to rest")
	check(item.global_position.y < 0.3, "item rests on the floor")
	check_eq(floor_body.thrown_hits, 0, "a spent item does not damage what it lands on")


func test_fragile_item_shatters_on_hit() -> void:
	_box(Vector3(4, 4, 0.5), Vector3(0, 1, -4))
	await wait_physics(2)
	var item: Throwable = Throwable.create(&"bottle")
	world.add_child(item)
	item.throw_from(Vector3(0, 1.4, 0), Vector3.FORWARD * T.throw_speed, null)
	await wait_physics(60)
	check(not is_instance_valid(item), "bottle should be gone")


func test_pickup_cone_and_hold_and_throw() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var player: Player = Game.player
	var ahead: Vector3 = player.aim_origin() + player.aim_direction() * 1.8
	var pistol: Pistol = Pistol.create()
	Game.entities_root(self).add_child(pistol)
	pistol.global_position = ahead
	var behind: Throwable = Throwable.create(&"mug")
	Game.entities_root(self).add_child(behind)
	behind.global_position = player.aim_origin() - player.aim_direction() * 1.8
	await wait_physics(2)
	check(player.hands.find_target() == pistol, "targets the pistol in front, not the mug behind")
	check(player.hands.pick_up(pistol), "pick up succeeds")
	check(player.hands.held == pistol, "pistol is held")
	check_eq(pistol.state, Pickup.State.HELD, "state is held")
	check(player.hands.find_target() == null, "nothing else in the cone")
	player.hands.primary()
	check_eq(pistol.ammo, T.pistol_ammo - 1, "primary fires the pistol")
	player.hands.secondary()
	check(player.hands.held == null, "secondary throws it")
	check_eq(pistol.state, Pickup.State.FLYING, "pistol is flying")


func test_punch_hits_and_cools_down_on_world_time() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var player: Player = Game.player
	var target: Dummy = _box(Vector3(1, 2, 1), player.aim_origin() + player.aim_direction() * 1.2, 4)
	await wait_physics(2)
	check(player.hands.punch(), "first punch")
	check_eq(target.punches, 1, "target punched")
	check(not player.hands.punch(), "second punch blocked by cooldown")
	await wait_physics(int(T.punch_cooldown * 60.0) + 4)
	check(player.hands.punch(), "punch again after cooldown")
	check_eq(target.punches, 2, "two punches landed")
