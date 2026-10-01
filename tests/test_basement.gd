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
	for node: Node in get_tree().get_nodes_in_group(&"lurkers"):
		(node as VentLurker).take_damage(9)
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


## It is not a boss fight: no bar, no name over the room, and it is not standing in the middle
## of the floor waiting for you. Most of the time it is a puddle.
func test_the_thing_down_there_is_not_a_boss() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var it: Beast = null
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if node is Beast:
			it = node
	check(it != null, "it is down there")
	check_eq(get_tree().get_nodes_in_group(&"bosses").size(), 0, "and nothing on this floor is a boss")
	check(not it.has_method(&"boss_name"), "it has no name for a bar")
	check_eq(it.form, Beast.Form.LIQUID, "it starts as a puddle")
	check(it.liquid(), "which is nothing you can shoot")
	var skin: ShaderMaterial = it.body_material as ShaderMaterial
	check(skin != null and (skin.get_shader_parameter(&"low_colour") as Color).g > 0.5, "green at the bottom")
	check((skin.get_shader_parameter(&"high_colour") as Color).r > 0.5, "red at the top")


func test_it_runs_as_liquid_and_pours_up_into_a_shape_when_you_are_close() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var it: Beast = null
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if node is Beast:
			it = node
	it.sense_override = true
	it.can_see_player = true
	it.alerted = true
	var rounds: int = 0
	it.on_bullet_hit(null, it.global_position, Vector3.UP)
	check_eq(it.hp_left, T.beast_hp, "a round goes straight through it while it is liquid")
	# Stand next to it and it comes up out of the floor. It normally keeps away for a few
	# seconds first; this is about what it does when it decides to come, not the waiting.
	it._patience = 0.0
	Game.player.global_position = it.global_position + Vector3(1.2, 0.05, 0)
	var rose: Dictionary = {"yes": false}
	it.rose_up.connect(func() -> void: rose["yes"] = true, CONNECT_ONE_SHOT)
	for i: int in 400:
		await wait_physics(1)
		it.dist_to_player = it.flat_distance_to(Game.player.global_position)
		if rose["yes"]:
			break
	check(rose["yes"], "it came up in front of you")
	check_eq(it.form, Beast.Form.SOLID, "and now it is a thing with a shape")
	check(not it.liquid(), "which can be shot (form %d, hp %d)" % [it.form, it.hp_left])
	var before: int = it.hp_left
	for i: int in T.beast_hits_before_it_melts:
		it.on_bullet_hit(null, it.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	check_eq(it.hp_left, before - T.beast_hits_before_it_melts, "rounds tell on it (form now %d)" % it.form)
	await wait_physics(4)
	check(it.form == Beast.Form.SINKING or it.form == Beast.Form.LIQUID, "then it gives up the shape and goes")


func test_everyone_down_there_wears_the_same_colours() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var gradient: int = 0
	var dudes: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		# Only the ones grown down here: a knifeman or a spearman walked in wearing his own.
		if dude == null or dude.get_script() != preload("res://enemies/pink_dude.gd"):
			continue
		dudes += 1
		gradient += 1 if dude.skin.material is ShaderMaterial else 0
	check(dudes >= 4, "there are people down there, got %d" % dudes)
	check_eq(gradient, dudes, "and every one of them is red over green, not pink")


func test_the_lights_down_there_are_on_their_way_out() -> void:
	check(Game.load_floor(12), "the basement loads")
	await wait_physics(4)
	var lamps: Array[Node] = get_tree().get_nodes_in_group(&"flicker_lamps")
	check(lamps.size() >= 6, "strip lights through the rooms, got %d" % lamps.size())
	var lamp: FlickerLamp = lamps[0]
	var brightest: float = 0.0
	var dimmest: float = 100.0
	for i: int in 240:
		await wait_physics(1)
		var energy: float = (lamp.get_child(2) as OmniLight3D).light_energy
		brightest = maxf(brightest, energy)
		dimmest = minf(dimmest, energy)
	check(brightest > 0.5 and dimmest < 0.2, "and it flickers: %.2f down to %.2f" % [brightest, dimmest])


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
