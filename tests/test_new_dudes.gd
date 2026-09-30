extends "res://tests/test_case.gd"
## Runners, biters, the Brute, the Warden, the super gun reward and saved progress.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.start_run_state_for_tests()


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.start_run_state_for_tests()
	Game.unload_level()


func _clear_room() -> Vector3:
	check(Game.load_level("test_room"), "level loads")
	await LevelValidator.wait_until_synced(Game.level, Game.data)
	for group: StringName in [&"enemies", &"barrels", &"buried"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	Game.alive_enemies = 0
	return Game.data.cell_center(Vector2i(9, 8), 0.05)


func test_runner_is_faster_than_the_player_unarmed_and_never_hides() -> void:
	var spot: Vector3 = await _clear_room()
	var runner: Runner = Game.spawn_dude(spot, true, &"runner") as Runner
	check(runner != null, "spawned a Runner")
	check(runner.move_speed() > T.walk_speed, "faster than you can walk (%.1f vs %.1f)" % [runner.move_speed(), T.walk_speed])
	check(not runner.has_weapon() and not runner.seeks_cover(), "fists, no cover")
	check_eq(runner.body_material, Mats.hot_pink(), "hot pink so you can tell")


func test_runner_actually_closes_the_distance() -> void:
	var spot: Vector3 = await _clear_room()
	Game.player.global_position = Game.data.cell_center(Vector2i(2, 8), 0.05)
	var runner: PinkDude = Game.spawn_dude(spot, true, &"runner")      # open floor between them
	runner.alerted = true
	var start: float = runner.global_position.distance_to(Game.player.global_position)
	await wait_physics(120)
	var now: float = runner.global_position.distance_to(Game.player.global_position)
	check(start - now > 8.0, "he covered %.1f m in two seconds" % (start - now))


func test_knifeman_is_orange_rushes_and_cuts_from_further_than_a_fist() -> void:
	var spot: Vector3 = await _clear_room()
	Game.god_mode = false
	Game.player.global_position = spot + Vector3(-4, 0.05, 0)
	var blade: Knifeman = Game.spawn_dude(spot, false, &"knifeman") as Knifeman
	blade.alerted = true
	check_eq(blade.skin.material, Mats.knifeman(), "burnt orange, not pink")
	check(blade.has_knife, "with a knife in his hand")
	check(blade.punch_range() > T.dude_punch_range + 0.4, "and he reaches further than a fist")
	check(blade.move_speed() > T.dude_speed, "and he is quick")
	for i: int in 400:
		await wait_physics(1)
		if not Game.player.alive:
			break
	check(not Game.player.alive, "he cut you")


func test_the_knifeman_throws_the_blade_if_you_keep_away_and_drops_one_when_killed() -> void:
	var spot: Vector3 = await _clear_room()
	var blade: Knifeman = Game.spawn_dude(spot, false, &"knifeman") as Knifeman
	blade.sense_override = true
	blade.can_see_player = true
	blade.dist_to_player = 8.0
	blade.set_physics_process(false)      # hold him at arm's length and let his patience run out
	blade._out_of_reach = T.knifeman_throw_wait
	blade.set_physics_process(true)
	for i: int in 200:
		await wait_physics(1)
		if not blade.has_knife:
			break
	check(not blade.has_knife, "the knife went to you instead")
	var flying: Array = get_tree().get_nodes_in_group(&"pickups").filter(func(k: Pickup) -> bool: return k is Knife)
	check(flying.size() >= 1, "and it is in the air")
	check_eq(blade.punch_range(), T.dude_punch_range, "without it he is down to his fists")
	blade.die()
	await wait_physics(3)
	var knives: int = get_tree().get_nodes_in_group(&"pickups").filter(func(k: Pickup) -> bool: return k is Knife).size()
	check_eq(knives, 1, "he had nothing left to drop")


func test_spearman_is_violet_slow_and_kills_from_outside_your_reach() -> void:
	var spot: Vector3 = await _clear_room()
	Game.god_mode = false
	Game.player.global_position = spot + Vector3(-5, 0.05, 0)
	var pike: Spearman = Game.spawn_dude(spot, false, &"spearman") as Spearman
	pike.alerted = true
	check_eq(pike.skin.material, Mats.spearman(), "violet")
	check(pike.punch_range() > T.punch_range, "his reach beats yours: %.1f m against your %.1f" % [pike.punch_range(), T.punch_range])
	check(pike.move_speed() < T.walk_speed, "but you can walk away from him")
	for i: int in 500:
		await wait_physics(1)
		if not Game.player.alive:
			break
	check(not Game.player.alive, "he ran you through")


func test_a_dead_spearman_leaves_his_spear() -> void:
	var spot: Vector3 = await _clear_room()
	var pike: PinkDude = Game.spawn_dude(spot, false, &"spearman")
	await wait_physics(2)
	pike.die()
	await wait_physics(3)
	var spears: Array = get_tree().get_nodes_in_group(&"pickups").filter(func(x: Pickup) -> bool: return x is Spear)
	check_eq(spears.size(), 1, "one spear on the floor, yours if you want it")


func test_cloner_keeps_away_and_makes_copies_that_cannot_copy() -> void:
	var spot: Vector3 = await _clear_room()
	Game.player.global_position = spot + Vector3(-6, 0.05, 0)
	var maker: Cloner = Game.spawn_dude(spot, false, &"cloner") as Cloner
	maker.sense_override = true
	maker.alerted = true
	check_eq(maker.skin.material, Mats.cloner(), "mint white")
	var counted: int = Game.alive_enemies
	for i: int in 900:
		await wait_physics(1)
		if maker.alive_copies() >= T.cloner_at_once:
			break
	check_eq(maker.alive_copies(), T.cloner_at_once, "he fills the room to his limit")
	check_eq(Game.alive_enemies, counted + T.cloner_at_once, "and every copy counts as an enemy")
	var copy: Cloner = maker.copies[0]
	check(copy.is_copy and copy.made == 0, "a copy never makes copies")
	check_eq(copy.skin.material, Mats.clone_copy(), "and is a paler thing than he is")
	await wait_physics(240)
	check(maker.alive_copies() <= T.cloner_at_once, "never more than his limit at once")
	check(maker.global_position.distance_to(Game.player.global_position) > 4.0, "he keeps his distance")


func test_killing_the_cloner_takes_every_copy_with_him() -> void:
	var spot: Vector3 = await _clear_room()
	Game.player.global_position = spot + Vector3(-6, 0.05, 0)
	var maker: Cloner = Game.spawn_dude(spot, false, &"cloner") as Cloner
	maker.sense_override = true
	maker.alerted = true
	for i: int in 900:
		await wait_physics(1)
		if maker.alive_copies() >= 2:
			break
	check(maker.alive_copies() >= 2, "copies are out")
	var his: Array = maker.copies.duplicate()
	maker.die()
	await wait_physics(4)
	var still_up: int = 0
	for c: Variant in his:
		if is_instance_valid(c) and (c as Cloner).alive:
			still_up += 1
	check_eq(still_up, 0, "they go when he goes")
	check_eq(Game.alive_enemies, 0, "and the floor is clear")


func test_brute_is_huge_takes_twelve_hits_and_calls_waves() -> void:
	check(Game.load_level("f10_vault"), "vault loads")
	await wait_physics(3)
	var brute: Brute = get_tree().get_first_node_in_group(&"bosses") as Brute
	check(brute != null, "the Brute is here")
	brute.sense_override = true
	check(brute.body_scale > 1.6 and brute.body_bulk() > 1.4, "big and buff")
	check_eq(brute.boss_health(), Vector2i(12, 12), "twelve hits")
	check(Game.data.initial_enemy_count() >= 7, "with protectors round him")
	var before: int = Game.alive_enemies
	for i: int in 4:
		brute.on_bullet_hit(null, brute.global_position + Vector3.UP, Vector3.LEFT)
	check(Game.alive_enemies > before, "a third down, reinforcements")
	for i: int in 8:
		brute.on_bullet_hit(null, brute.global_position + Vector3.UP, Vector3.LEFT)
	check(not brute.alive, "down on the twelfth")


func test_brute_slam_kills_a_player_who_lets_him_close() -> void:
	var spot: Vector3 = await _clear_room()
	Game.god_mode = false
	var brute := Brute.new()
	Game.entities_root(self).add_child(brute)
	brute.global_position = spot
	Game.player.global_position = spot + Vector3(-1.8, 0.05, 0)
	for i: int in 120:
		await wait_physics(1)
		if not Game.player.alive:
			break
	check(not Game.player.alive, "both fists")


func test_warden_needs_three_rounds_through_the_glass() -> void:
	check(Game.load_level("f21_lockdown"), "lockdown loads")
	await wait_physics(3)
	var warden: Warden = get_tree().get_first_node_in_group(&"bosses") as Warden
	check(warden != null, "the Warden is here")
	warden.sense_override = true
	check_eq(warden.boss_health(), Vector2i(3, 3), "three")
	var before: int = Game.alive_enemies
	warden.visor_shot(Vector3.RIGHT)
	check(warden.alive and warden.shield.glass_intact, "one: he reels, the glass holds")
	check(Game.alive_enemies > before, "and help arrives")
	warden.on_bullet_hit(null, warden.global_position + Vector3.UP, Vector3.LEFT)
	check_eq(warden.glass_left, 2, "a body shot does nothing")
	warden.visor_shot(Vector3.RIGHT)
	warden.visor_shot(Vector3.RIGHT)
	check(not warden.alive, "three: down")


func test_bosses_sit_on_the_right_floors_and_there_are_forty() -> void:
	check_eq(Game.FLOORS.size(), 40, "thirty in the tower and ten on the station")
	check_eq(LevelParser.load_level(Game.FLOORS[9]).boss_kind, &"brute", "level 10 is the Brute")
	check_eq(LevelParser.load_level(Game.FLOORS[20]).boss_kind, &"warden", "level 21 is the Warden")
	check(LevelParser.load_level(Game.FLOORS[29]).boss_cell.x >= 0, "level 30 is the Director")
	for i: int in [9, 20, 29]:
		check(LevelParser.load_level(Game.FLOORS[i]).boss_cell.x >= 0, "%s has a boss" % Game.FLOORS[i])


func test_floors_use_the_new_toys_where_promised() -> void:
	var with_fart: PackedStringArray = []
	var totals: Dictionary[String, int] = {}
	for floor_name: String in Game.FLOORS:
		var d: LevelData = LevelParser.load_level(floor_name)
		for p: Dictionary in d.pickups:
			if p["kind"] == &"fart" and not with_fart.has(floor_name):
				with_fart.append(floor_name)
		totals["water"] = totals.get("water", 0) + d.puddles.size()
		for p: Dictionary in d.pickups:
			totals[String(p["kind"])] = totals.get(String(p["kind"]), 0) + 1
		for sp: Dictionary in d.spawns:
			totals["dude_" + String(sp["weapon"])] = totals.get("dude_" + String(sp["weapon"]), 0) + 1
	check(with_fart.has("f15_restrooms") and with_fart.has("f18_beanworks"), "stink grenades on 15 and 18: %s" % ", ".join(with_fart))
	check(with_fart.size() < Game.FLOORS.size() / 2, "but not everywhere (%d of %d floors)" % [with_fart.size(), Game.FLOORS.size()])
	for key: String in ["knife", "freeze", "smg", "revolver", "sniper", "dude_runner", "dude_knifeman", "dude_spearman", "dude_sniper", "dude_smg"]:
		check(totals.get(key, 0) >= 5, "%s appears %d times across the game" % [key, totals.get(key, 0)])
	check(totals["water"] > 300, "plenty of wet floor (%d cells)" % totals["water"])


func test_each_new_floor_has_its_own_look() -> void:
	var seen: Dictionary[String, String] = {}
	for i: int in range(5, 29):
		var d: LevelData = LevelParser.load_level(Game.FLOORS[i])
		check(d.theme.has("wall") and d.theme.has("floor"), "%s has a theme" % Game.FLOORS[i])
		var key: String = "%s/%s" % [d.theme.get("wall", ""), d.theme.get("floor", "")]
		check(not seen.has(key), "%s shares its colours with %s" % [Game.FLOORS[i], seen.get(key, "")])
		seen[key] = Game.FLOORS[i]


func test_progress_is_saved_and_continue_picks_it_up() -> void:
	Game.god_mode = false
	Game.best_floor = 0
	check(Game.load_floor(6), "floor 7 loads")
	check_eq(Game.best_floor, 6, "remembered")
	Game.best_floor = 0
	Game.load_progress()
	check_eq(Game.best_floor, 6, "read back from disk")
	Game.erase_progress()
	Game.load_progress()
	check_eq(Game.best_floor, 0, "new game wipes it")
