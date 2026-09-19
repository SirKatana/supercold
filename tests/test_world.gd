extends "res://tests/test_case.gd"

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	TimeManager.override_scale = 1.0
	Game.god_mode = true
	await wait_frames(1)


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _door() -> Door:
	var door := Door.new()
	world.add_child(door)
	return door


func test_door_damage_table() -> void:
	check_eq(Door.damage_for(&"punch"), 1, "punch")
	check_eq(Door.damage_for(&"throw"), 2, "throw")
	check_eq(Door.damage_for(&"bullet"), 1, "bullet")
	check_eq(T.door_hp, 2, "door hp")


func test_door_takes_two_punches() -> void:
	var door: Door = _door()
	door.on_punched(self, Vector3.ZERO)
	check(not door.is_broken, "one punch is not enough")
	door.on_punched(self, Vector3.ZERO)
	check(door.is_broken, "two punches break it")


func test_door_breaks_to_one_throw() -> void:
	var door: Door = _door()
	var item: Throwable = Throwable.create(&"keyboard")
	world.add_child(item)
	item.velocity = Vector3.FORWARD * 10.0
	door.on_thrown_hit(item)
	check(door.is_broken, "one thrown item breaks it")


func test_door_takes_two_bullets() -> void:
	var door: Door = _door()
	door.on_bullet_hit(null, Vector3.ZERO, Vector3.UP)
	check(not door.is_broken, "one bullet is not enough")
	door.on_bullet_hit(null, Vector3.ZERO, Vector3.UP)
	check(door.is_broken, "two bullets break it")


func test_breaking_a_door_stuns_the_dude_behind_it() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var door: Door = get_tree().get_first_node_in_group(&"doors") as Door
	check(door != null, "door was built")
	var dude: PinkDude = Game.spawn_dude(door.global_position + Vector3(1.2, 0, 0), true)
	var far: PinkDude = Game.spawn_dude(door.global_position + Vector3(7.0, 0, 0), true)
	await wait_physics(1)
	door.take_damage(5, Vector3.RIGHT, door.global_position)
	check_eq(dude.state_name, &"stunned", "dude behind the door is stunned")
	check(far.state_name != &"stunned", "dude far away is not")
	await wait_frames(2)
	check(not is_instance_valid(door), "door is gone")


func test_door_opens_for_dudes() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var door: Door = get_tree().get_first_node_in_group(&"doors") as Door
	check(not door.is_open(), "closed when nobody is near")
	Game.spawn_dude(door.global_position + Vector3(1.0, 0, 0), true)
	await wait_physics(40)
	check(door.is_open(), "opens for a dude standing next to it")


func test_glass_blocks_walking_but_not_sight() -> void:
	var pane := GlassPane.new()
	world.add_child(pane)
	pane.global_position = Vector3(0, 0, -3)
	await wait_physics(2)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	check(Sight.is_clear(space, Vector3(0, 1.5, 0), Vector3(0, 1.5, -6)), "can see through glass")
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, 0), Vector3(0, 1.5, -6), 1)
	check(not space.intersect_ray(query).is_empty(), "glass is solid on the world layer")


func test_wall_blocks_sight() -> void:
	var wall: StaticBody3D = LevelBuilder.make_box(Vector3(4, 3, 0.5), Mats.wall())
	world.add_child(wall)
	wall.global_position = Vector3(0, 1.5, -3)
	await wait_physics(2)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	check(not Sight.is_clear(space, Vector3(0, 1.5, 0), Vector3(0, 1.5, -6)), "wall blocks sight")


func test_glass_breaks_on_bullet() -> void:
	var pane := GlassPane.new()
	world.add_child(pane)
	pane.global_position = Vector3(0, 0, -3)
	await wait_physics(2)
	BulletPool.for_node(world).fire(Vector3(0, 1.5, 0), Vector3.FORWARD, null)
	await wait_physics(40)
	check(not is_instance_valid(pane), "glass is gone")


func test_reachability_passes_on_test_rooms() -> void:
	for level_name: String in ["test_room", "test_doors"]:
		check(Game.load_level(level_name), "%s loads" % level_name)
		check(await LevelValidator.wait_until_synced(Game.level, Game.data), "%s nav synced" % level_name)
		var problems: PackedStringArray = LevelValidator.unreachable(Game.level, Game.data)
		check(problems.is_empty(), "%s: %s" % [level_name, ", ".join(problems)])


func test_reachability_catches_a_sealed_room() -> void:
	check(Game.load_level("test_sealed"), "level loads")
	check(await LevelValidator.wait_until_synced(Game.level, Game.data), "nav synced")
	var problems: PackedStringArray = LevelValidator.unreachable(Game.level, Game.data)
	check_eq(problems.size(), 2, "exit and enemy are both walled off: %s" % ", ".join(problems))


func test_player_death_restarts_floor() -> void:
	Game.god_mode = false
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var first: Player = Game.player
	first.die()
	check_eq(Game.state, Game.State.DEAD, "dead state")
	await get_tree().create_timer(T.death_restart_delay + 0.3, true, false, true).timeout
	await wait_physics(2)
	check_eq(Game.state, Game.State.PLAYING, "playing again")
	check(Game.player != first and Game.player.alive, "fresh player")


func test_wave_spawns_after_kills() -> void:
	var data: LevelData = LevelParser.parse("#######\n#P.a.w#\n#..X..#\n#######",
		'{"waves":[{"after_kills":1,"count":3,"armed":2}]}')
	check(data.errors.is_empty(), "parses")
	check_eq(data.waves.size(), 1, "one wave")
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(2)
	Game.data.wave_points = [Vector2i(7, 2)]
	Game._pending_waves = [{"after_kills": 1, "on_trigger": false, "count": 3, "armed": 2}]
	check(not Game.is_floor_clear(), "pending wave keeps the floor open")
	(get_tree().get_first_node_in_group(&"enemies") as PinkDude).die()
	await wait_physics(2)
	check_eq(Game.alive_enemies, 3, "wave of three arrived")
	check_eq(Game.state, Game.State.PLAYING, "floor not clear yet")
