extends "res://tests/test_case.gd"
## Picking a dead man up and throwing him at a live one.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(3)
	# The room's own dudes are in the way of a thrown body, which is realistic and useless for
	# a test: one corpse, one victim, nobody else.
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	Game.alive_enemies = 0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	if Game.player != null and is_instance_valid(Game.player):
		Game.player.hands.carried_body = null
	Game.unload_level()


func _a_settled_body() -> Ragdoll:
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(1.4, 0, 0)
	await wait_physics(2)
	dude.die()
	for step: int in 400:
		await wait_physics(1)
		var body: Ragdoll = get_tree().get_first_node_in_group(&"ragdolls") as Ragdoll
		if body != null and body.liftable():
			return body
	return get_tree().get_first_node_in_group(&"ragdolls") as Ragdoll


func test_a_body_can_be_picked_up_once_it_has_stopped_moving() -> void:
	var body: Ragdoll = await _a_settled_body()
	check(body != null, "there is a body on the floor")
	check(body.liftable(), "and it has settled")
	Game.player.hands.interact()
	check(Game.player.hands.carried_body == body, "it is over your shoulder")
	check(body.carried_by == Game.player, "and it knows who has it")
	await wait_physics(10)
	check(body.point(&"chest").distance_to(Game.player.global_position) < 2.0, "it travels with you")


func test_a_body_in_mid_air_cannot_be_grabbed() -> void:
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(1.4, 0, 0)
	await wait_physics(2)
	dude.die()
	await wait_physics(2)
	var body: Ragdoll = get_tree().get_first_node_in_group(&"ragdolls") as Ragdoll
	check(body != null, "he is on his way down")
	check(not body.liftable(), "and you cannot catch him mid-fall")


func test_a_thrown_body_knocks_a_dude_over_without_killing_him() -> void:
	var body: Ragdoll = await _a_settled_body()
	Game.player.hands.interact()
	check(Game.player.hands.carried_body == body, "carrying one")
	var victim := PinkDude.new()
	Game.entities_root(self).add_child(victim)
	victim.sense_override = true
	await wait_physics(2)
	victim.global_position = body.point(&"chest") + Game.player.aim_direction() * 2.0
	Game.player.hands.throw_held()
	check(Game.player.hands.carried_body == null, "it has left your hands")
	check(body.thrown_for > 0.0, "and it is dangerous while it flies")
	for step: int in 400:
		await wait_physics(1)
		if victim.flung:
			break
	check(victim.alive, "it did not kill him")
	check(victim.flung, "but it took him off his feet")
	victim.queue_free()
