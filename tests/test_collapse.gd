extends "res://tests/test_case.gd"
## Bringing the shelves down, and what that does to whoever is under them.


func before_each() -> void:
	Game.god_mode = true
	TimeManager.override_scale = 1.0


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _a_shelf() -> Shelving:
	for node: Node in get_tree().get_nodes_in_group(&"shelving"):
		return node as Shelving
	return null


func test_shelving_takes_a_few_hits_then_goes_over() -> void:
	check(Game.load_level("f3_servers"), "a floor with shelving loads")
	await wait_physics(3)
	var shelf: Shelving = _a_shelf()
	check(shelf != null, "there is a run of it")
	check(not shelf.down, "standing to start with")
	shelf.on_punched(Game.player, shelf.global_position)
	check(not shelf.down, "one punch is not enough")
	shelf.take_damage(9, Vector3.FORWARD)
	check(shelf.down, "but enough of them brings it down")
	await wait_physics(3)
	for child: Node in shelf.get_children():
		if child is MeshInstance3D:
			check(not (child as MeshInstance3D).visible, "the shelves themselves are gone")


func test_what_is_left_is_still_cover_but_lower() -> void:
	check(Game.load_level("f3_servers"), "floor loads")
	await wait_physics(3)
	var shelf: Shelving = _a_shelf()
	var before: float = ((shelf.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.y
	shelf.smash(Vector3.FORWARD)
	await wait_physics(2)
	var after: float = ((shelf.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.y
	check(after < before, "the heap is lower than the shelving was (%.2f against %.2f)" % [after, before])
	check(after > 0.3, "but there is still something to hide behind")


func test_a_dude_under_it_ends_up_limping_not_dead() -> void:
	check(Game.load_level("f3_servers"), "floor loads")
	await wait_physics(3)
	var shelf: Shelving = _a_shelf()
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = shelf.global_position
	dude.sense_override = true
	await wait_physics(2)
	shelf.smash(Vector3.FORWARD)
	await wait_physics(2)
	check(dude.alive, "it did not kill him")
	check(dude.limping, "but he is not walking it off")
	check(dude.move_speed() < T.dude_speed, "and he is slower for it (%.2f)" % dude.move_speed())
	dude.queue_free()


func test_a_falling_pot_breaks_and_hurts_without_killing() -> void:
	check(Game.load_level("f3_servers"), "floor loads")
	await wait_physics(3)
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.global_position = Game.player.global_position + Vector3(2.5, 0, 0)
	dude.sense_override = true
	await wait_physics(2)
	var pot := FallingPot.new()
	Game.entities_root(self).add_child(pot)
	pot.global_position = dude.global_position + Vector3(0, 2.0, 0)
	for step: int in 180:
		await wait_physics(1)
		if not is_instance_valid(pot):
			break
	check(not is_instance_valid(pot), "it broke on the floor")
	check(dude.alive, "the plant did not kill anybody")
	check(dude.limping, "but he felt it")
	dude.queue_free()
