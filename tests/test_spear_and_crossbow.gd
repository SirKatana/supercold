extends "res://tests/test_case.gd"
## The two new weapons: a spear that reaches, and a crossbow nobody hears.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.fast_elevators = true
	check(Game.load_level("test_room"), "test room loads")
	# Out of the arrival lift before any shooting: its doors are solid, and a round fired from
	# inside one hits them, which is the right behaviour and the wrong test.
	await wait_physics(3)
	Game.player.global_position += -Game.player.global_transform.basis.z * 2.5
	await wait_physics(4)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


## A dude who is dead may already have been cleaned up.
func _gone(d: Variant) -> bool:
	return not is_instance_valid(d) or not (d as PinkDude).alive


func _dude_ahead(distance: float) -> PinkDude:
	var p: Player = Game.player
	var dude: PinkDude = Game.spawn_dude(p.global_position - p.global_transform.basis.z * distance, true)
	dude.sense_override = true
	dude.set_physics_process(false)      # he stands where he is put: this is about the weapon
	return dude


func test_the_spear_kills_from_further_than_a_fist_or_a_knife() -> void:
	check(T.spear_range > T.knife_range + 0.8, "it reaches %.1f m against the knife's %.1f" % [T.spear_range, T.knife_range])
	var spear: Spear = Spear.create()
	Game.entities_root(self).add_child(spear)
	Game.player.hands.pick_up(spear)
	var far: PinkDude = _dude_ahead(T.knife_range + 0.7)
	await wait_physics(2)
	Game.player.hands.primary()
	await wait_physics(2)
	check(_gone(far), "a man a knife could not touch is dead")
	check(spear.cooldown_left > 0.0, "and it takes a moment to bring back")


func test_the_spear_is_a_weapon_you_can_also_throw() -> void:
	var spear: Spear = Spear.create()
	Game.entities_root(self).add_child(spear)
	check(spear.is_weapon(), "security will want it back")
	Game.player.hands.pick_up(spear)
	var dude: PinkDude = _dude_ahead(6.0)
	await wait_physics(2)
	Game.player.hands.throw_held()
	for i: int in 120:
		await wait_physics(1)
		if _gone(dude):
			break
	check(_gone(dude), "thrown, it kills")


func test_the_crossbow_is_quiet_and_its_bolt_goes_through_two() -> void:
	var bow: Crossbow = Crossbow.create()
	check(bow.silent and bow.pierce >= 2, "quiet, and it pierces")
	Game.entities_root(self).add_child(bow)
	Game.player.hands.pick_up(bow)
	# Close together and in line: a shot converges on whatever the crosshair is on, which is the
	# near one, so the far one has to be right behind him.
	var first: PinkDude = _dude_ahead(4.0)
	var second: PinkDude = _dude_ahead(5.0)
	var listener: PinkDude = Game.spawn_dude(Game.player.global_position + Game.player.global_transform.basis.x * 9.0, true)
	listener.sense_override = true
	listener.alerted = false
	# Aim at the far one: a shot leaves the muzzle and converges on whatever the crosshair is
	# on, so the two have to be lined up with that point, not just with each other.
	Game.player.look_at(Vector3(second.global_position.x, Game.player.global_position.y, second.global_position.z))
	Game.player.head.rotation.x = 0.0
	await wait_physics(2)
	var where_first: Vector3 = first.global_position
	var where_second: Vector3 = second.global_position
	Game.player.hands.primary()
	for i: int in 90:
		await wait_physics(1)
		if _gone(second):
			break
	check(absf(where_first.z - where_second.z) < 0.4 and absf(where_first.y - where_second.y) < 0.4,
		"the two of them are in line: %s and %s" % [where_first, where_second])
	check(_gone(first) and _gone(second), "one bolt, two dudes (first gone %s, second gone %s, first at %s)" % [
		_gone(first), _gone(second), first.global_position if is_instance_valid(first) else Vector3.ZERO])
	check(not listener.alerted, "and the man round the corner heard nothing")


func test_a_pistol_shot_does_bring_them() -> void:
	var gun: Pistol = Pistol.create()
	Game.entities_root(self).add_child(gun)
	Game.player.hands.pick_up(gun)
	var listener: PinkDude = Game.spawn_dude(Game.player.global_position + Game.player.global_transform.basis.x * 9.0, true)
	listener.sense_override = true
	listener.alerted = false
	await wait_physics(2)
	Game.player.hands.primary()
	await wait_physics(4)
	check(listener.alerted, "a gunshot is heard: that is what the crossbow is for")


func test_both_are_on_the_floors_and_in_the_guard_s_book() -> void:
	var spears: int = 0
	var bows: int = 0
	for i: int in Game.FLOORS.size():
		for entry: Dictionary in LevelParser.load_level(Game.FLOORS[i]).pickups:
			spears += 1 if entry["kind"] == &"spear" else 0
			bows += 1 if entry["kind"] == &"crossbow" else 0
	check(spears >= 4 and bows >= 4, "spears %d, crossbows %d across the game" % [spears, bows])
	check(LevelBuilder.create_pickup(&"spear") is Spear, "the builder knows the spear")
	check(LevelBuilder.create_pickup(&"crossbow") is Crossbow, "and the crossbow")
