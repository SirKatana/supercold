extends "res://tests/test_case.gd"
## Anything the player throws at a pink dude hits him: long guns included.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _throw_at_a_dude(item: Pickup, distance: float, beside: float = 0.0) -> Array:
	var p: Player = Game.player
	var dude: PinkDude = Game.spawn_dude(p.global_position - p.global_transform.basis.z * distance + p.global_transform.basis.x * beside, true)
	dude.sense_override = true
	await wait_physics(2)
	Game.entities_root(self).add_child(item)
	p.hands.pick_up(item)
	p.head.rotation.x = -0.05
	await wait_physics(2)
	var hits: Array = []
	item.thrown_hit.connect(func(what: Object) -> void: hits.append(what))
	p.hands.throw_held()
	for i: int in 90:
		await wait_physics(1)
		if not hits.is_empty():
			break
	return [hits, dude, item]


func test_every_gun_thrown_at_a_dude_hits_him() -> void:
	for kind: StringName in [&"pistol", &"shotgun", &"rifle", &"smg", &"revolver", &"sniper"]:
		for distance: float in [0.9, 1.3, 1.8, 2.5, 5.0]:
			var got: Array = await _throw_at_a_dude(PinkDude.create_gun(kind), distance)
			check(not (got[0] as Array).is_empty() and got[0][0] == got[1], "%s thrown from %.1f m hits him" % [kind, distance])
			if is_instance_valid(got[1]):
				(got[1] as Node).free()
			if is_instance_valid(got[2]):
				(got[2] as Node).queue_free()
			Game.alive_enemies = 0
			await wait_physics(2)


## The centre of a spinning shotgun can pass a hand's width beside him while the gun itself
## sweeps straight through him. That has to count.
func test_a_long_gun_that_clips_him_hits_him() -> void:
	for kind: StringName in [&"shotgun", &"rifle", &"sniper"]:
		var got: Array = await _throw_at_a_dude(PinkDude.create_gun(kind), 3.0, 0.58)
		check(not (got[0] as Array).is_empty() and got[0][0] == got[1], "%s passing just beside his arm still hits him" % kind)
		if is_instance_valid(got[1]):
			(got[1] as Node).free()
		if is_instance_valid(got[2]):
			(got[2] as Node).queue_free()
		Game.alive_enemies = 0
		await wait_physics(2)


func test_a_pistol_that_misses_by_a_foot_misses() -> void:
	var got: Array = await _throw_at_a_dude(PinkDude.create_gun(&"pistol"), 3.0, 0.9)
	check((got[0] as Array).filter(func(w: Object) -> bool: return w == got[1]).is_empty(), "no magnet: a clear miss is a miss")
