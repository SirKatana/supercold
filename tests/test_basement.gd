extends "res://tests/test_case.gd"
## Level 13: the lift that goes the wrong way, and what is waiting at the bottom.


func before_each() -> void:
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	Game.fast_elevators = true
	Game.start_run_state_for_tests()


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.glitch = 0.0
	Game.start_run_state_for_tests()
	Game.unload_level()


func test_level_thirteen_is_not_on_the_buttons() -> void:
	check_eq(Game.FLOORS[12], Game.SECRET_FLOOR, "level 13 is the basement")
	check_eq(Game.floor_label(Game.SECRET_FLOOR), "LEVEL ????", "and it does not have a number")
	check_eq(Game.floor_label("f12_kitchen"), "LEVEL 12", "the one before it does")
	check_eq(Game.floor_label("f14_glassworks"), "LEVEL 14", "and so does the one after")
	check(not FileAccess.file_exists("res://levels/f13_coldstore.txt"), "the cold store is gone")


func test_the_lift_down_to_it_comes_apart() -> void:
	check(Game.load_floor(11), "the kitchen loads")
	await wait_physics(3)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		(node as PinkDude).die()
	await wait_physics(3)
	var lift: Elevator = get_tree().get_first_node_in_group(&"elevator") as Elevator
	check(lift.present, "the lift has arrived")
	check_eq(Game.glitch, 0.0, "and the picture is fine so far")
	lift.press()
	Game.player.global_position = lift.global_position
	var worst: float = 0.0
	var shaken: float = 0.0
	for i: int in 900:
		await wait_physics(1)
		worst = maxf(worst, Game.glitch)
		shaken = maxf(shaken, Game.player.fx._shake if "_shake" in Game.player.fx else 0.0)
		if Game.level_name == Game.SECRET_FLOOR:
			break
	check_eq(Game.level_name, Game.SECRET_FLOOR, "the lift went down to the basement")
	check(worst > 0.8, "the picture fell apart on the way (worst %.2f)" % worst)
	check(shaken > 0.0, "and the cabin shook")
	check_eq(Game.glitch, 0.0, "it is steady again once the doors open")


func test_the_basement_is_a_laboratory_with_a_broken_tank() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var tanks: Array[Node] = get_tree().get_nodes_in_group(&"tanks")
	check(tanks.size() >= 12, "rows of growing tanks, got %d" % tanks.size())
	var cracked: Array = tanks.filter(func(t: SpecimenTank) -> bool: return t.cracked)
	check(cracked.size() >= 1, "and one of them is broken open")
	var whole: SpecimenTank = tanks.filter(func(t: SpecimenTank) -> bool: return not t.cracked)[0]
	check(whole.find_children("*", "OmniLight3D", false, false).size() == 1, "the full ones are what lights the place")
	var fluid: Array[Node] = get_tree().get_nodes_in_group(&"puddles")
	var near_the_crack: int = 0
	for node: Node in fluid:
		if (node as Node3D).global_position.distance_to((cracked[0] as Node3D).global_position) < 5.0:
			near_the_crack += 1
	check(near_the_crack >= 3, "with its fluid across the floor, got %d cells" % near_the_crack)
	check(float(Game.data.theme.get("energy", 1.0)) < 0.25, "and it is dark down there")


func test_the_beast_is_the_boss_and_he_is_red_over_green() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var beast: Beast = get_tree().get_first_node_in_group(&"bosses") as Beast
	check(beast != null, "he is down there")
	check_eq(beast.boss_name(), "THE THING IN THE TANK", "with a name for the bar")
	check_eq(beast.boss_health(), Vector2i(T.beast_hp, T.beast_hp), "and %d rounds in him" % T.beast_hp)
	check(beast.body_scale > 1.5, "twice your size")
	var skin: ShaderMaterial = beast.skin.material as ShaderMaterial
	check(skin != null, "his colour is a gradient, not a flat pink")
	check((skin.get_shader_parameter(&"low_colour") as Color).g > 0.5, "green at the feet")
	check((skin.get_shader_parameter(&"high_colour") as Color).r > 0.5, "red at the head")
	check(not beast.can_freeze() and not beast.can_choke(), "and nothing clever works on him")


func test_he_charges_you_and_it_costs_him() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var beast: Beast = get_tree().get_first_node_in_group(&"bosses") as Beast
	beast.sense_override = true
	beast.can_see_player = true
	beast.alerted = true
	Game.player.global_position = beast.global_position - beast.global_transform.basis.z * 9.0
	var charged: bool = false
	for i: int in 600:
		await wait_physics(1)
		beast.dist_to_player = beast.flat_distance_to(Game.player.global_position)
		if beast._charging >= 0.0:
			charged = true
			break
	check(charged, "he put his head down and came")
	check(T.beast_charge_speed > T.walk_speed, "faster than you can walk, while it lasts")
	for i: int in 200:
		await wait_physics(1)
		if beast._charging < 0.0:
			break
	check(beast._charging < 0.0, "and then it is over")


func test_the_guards_fire_carrots() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var carrots: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude.weapon is CarrotGun:
			carrots += 1
	check(carrots >= 3, "guards with carrot guns, got %d" % carrots)
	var gun: CarrotGun = CarrotGun.create()
	check_eq(gun.bullet_style, &"carrot", "and what comes out is a carrot")
	check(gun.bullet_speed_scale < 1.0, "slower than a bullet, so you can see it coming")
	Game.entities_root(self).add_child(gun)
	var pool: BulletPool = BulletPool.for_node(Game.level)
	gun.fire(Game.player.global_position + Vector3(0, 1.4, 0), Vector3.FORWARD, Game.player, false)
	await wait_physics(2)
	var flying: Bullet = null
	for b: Node in pool.get_children():
		if b is Bullet and (b as Bullet).active:
			flying = b
	check(flying != null and flying.style == &"carrot", "the round in the air is a carrot")


func test_there_is_a_gun_by_the_lift() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var start: Vector3 = Game.data.cell_center(Game.data.player_start, 0.0)
	var nearest: float = 1000.0
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		var item: Pickup = node as Pickup
		if item is Gun:
			nearest = minf(nearest, item.global_position.distance_to(start))
	check(nearest < 6.0, "something to shoot him with is waiting by the doors (%.1f m)" % nearest)
