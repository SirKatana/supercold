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


func test_biter_waits_underground_rises_when_you_come_close_and_only_then_counts() -> void:
	var spot: Vector3 = await _clear_room()
	Game.player.global_position = spot + Vector3(-20, 0, 0)
	var biter: Zombie = Game.spawn_dude(spot, true, &"zombie") as Zombie
	await wait_physics(30)
	check(biter.buried and not biter.rising, "still under the floor")
	check_eq(Game.alive_enemies, 0, "and not counted as an enemy")
	check(not biter.skin.visible, "out of sight")
	Game.player.global_position = spot + Vector3(-5, 0, 0)
	await wait_physics(20)
	check(biter.rising, "he starts to climb out")
	check(biter.global_position.y < -0.3, "from below the floor (y=%.2f)" % biter.global_position.y)
	await wait_physics(int(T.zombie_rise_seconds * 60.0) + 10)
	check(not biter.buried, "up")
	check_eq(Game.alive_enemies, 1, "now he counts")
	check(biter.arm_raise_floor() > 0.8, "arms out in front")
	check(not biter.can_choke(), "and he does not breathe")


func test_biter_bites() -> void:
	var spot: Vector3 = await _clear_room()
	Game.god_mode = false
	Game.player.global_position = spot + Vector3(-3, 0.05, 0)
	Game.spawn_dude(spot, true, &"zombie")
	for i: int in 500:
		await wait_physics(1)
		if not Game.player.alive:
			break
	check(not Game.player.alive, "he got you")


func test_floor_with_only_buried_biters_left_counts_as_clear() -> void:
	var spot: Vector3 = await _clear_room()
	Game.player.global_position = spot + Vector3(-25, 0, 0)
	Game.spawn_dude(spot, true, &"zombie")
	var dude: PinkDude = Game.spawn_dude(spot + Vector3(3, 0, 0), true)
	dude.sense_override = true
	dude.die()
	await wait_physics(2)
	check_eq(Game.state, Game.State.CLEARED, "you never have to go digging for them")


func test_brute_is_huge_takes_twelve_hits_calls_waves_and_drops_the_super_gun() -> void:
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
	check(not Game.has_super_gun, "no prize yet")
	for i: int in 8:
		brute.on_bullet_hit(null, brute.global_position + Vector3.UP, Vector3.LEFT)
	check(not brute.alive, "down on the twelfth")
	check(Game.has_super_gun, "the super gun is yours")
	var prize: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		if node is SuperGun:
			prize = true
	check(prize, "and it is lying where he fell")


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


func test_player_starts_later_floors_holding_the_super_gun() -> void:
	Game.has_super_gun = true
	check(Game.load_level("f11_sewers"), "level loads")
	await wait_physics(2)
	check(Game.player.hands.held is SuperGun, "in hand from the first second")
	check_eq((Game.player.hands.held as SuperGun).ammo, T.super_charges, "fully charged")


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


func test_bosses_sit_on_the_right_floors_and_there_are_thirty() -> void:
	check_eq(Game.FLOORS.size(), 30, "thirty levels")
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
	check(with_fart.size() < 6, "but not everywhere (%d floors)" % with_fart.size())
	for key: String in ["knife", "freeze", "smg", "revolver", "sniper", "dude_runner", "dude_zombie", "dude_sniper", "dude_smg"]:
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
	Game.has_super_gun = false
	Game.load_progress()
	check_eq(Game.best_floor, 6, "read back from disk")
	Game.erase_progress()
	Game.load_progress()
	check_eq(Game.best_floor, 0, "new game wipes it")
