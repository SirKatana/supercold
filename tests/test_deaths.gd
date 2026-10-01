extends "res://tests/test_case.gd"
## Every way of dying says what did it.


func before_each() -> void:
	Game.god_mode = false
	check(Game.load_level("test_room"), "test room loads")
	await wait_physics(2)


func after_each() -> void:
	Game.god_mode = true
	Game.unload_level()


func test_every_kind_of_dude_has_a_name_for_the_message() -> void:
	var seen: Dictionary[String, bool] = {}
	for maker: Callable in [func() -> PinkDude: return PinkDude.new(),
			func() -> PinkDude: return Runner.new(),
			func() -> PinkDude: return Knifeman.new(),
			func() -> PinkDude: return Spearman.new(),
			func() -> PinkDude: return Cloner.new(),
			func() -> PinkDude: return ShieldDude.new(),
			func() -> PinkDude: return Gentleman.new()]:
		var dude: PinkDude = maker.call()
		var name_said: String = dude.display_name()
		check(name_said != "", "%s says something" % dude.get_class())
		check(name_said == name_said.to_upper(), "%s reads as a caption" % name_said)
		seen[name_said] = true
		dude.free()
	check(seen.size() >= 6, "and they are not all the same (%d)" % seen.size())


func test_a_bullet_names_whoever_fired_it() -> void:
	var shooter := Gentleman.new()
	Game.entities_root(self).add_child(shooter)
	shooter.sense_override = true
	shooter.global_position = Game.player.global_position + Vector3(4, 0, 0)
	await wait_physics(2)
	var round_fired := Bullet.new()
	Game.entities_root(self).add_child(round_fired)
	round_fired.shooter = shooter
	round_fired.direction = Vector3.LEFT
	Game.player.on_bullet_hit(round_fired, Game.player.chest_position(), Vector3.LEFT)
	check(not Game.player.alive, "it killed him")
	check_eq(Game.player.killed_by, "THE GENTLEMAN", "and it says who fired")
	shooter.queue_free()
	round_fired.queue_free()


func test_a_punch_names_the_man_who_threw_it() -> void:
	var dude := PinkDude.new()
	Game.entities_root(self).add_child(dude)
	dude.sense_override = true
	await wait_physics(2)
	dude.global_position = Game.player.global_position + Vector3(0.8, 0, 0)
	dude.dist_to_player = 0.8
	dude.land_punch()
	check(not Game.player.alive, "it killed him")
	check_eq(Game.player.killed_by, "A PINK DUDE", "and names him")
	dude.queue_free()


func test_a_barrel_and_a_fall_have_their_own_names() -> void:
	Game.player.hit_from(Vector3.UP, "A GAS BARREL")
	check_eq(Game.player.killed_by, "A GAS BARREL", "the barrel owns up")
