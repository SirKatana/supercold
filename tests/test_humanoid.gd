extends "res://tests/test_case.gd"

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	TimeManager.override_scale = 1.0
	Game.god_mode = true


func after_each() -> void:
	TimeManager.override_scale = -1.0
	Game.god_mode = false
	Game.unload_level()


func _j(pose: PackedVector3Array, joint: StringName) -> Vector3:
	return pose[Humanoid.index_of(joint)]


func _len(pose: PackedVector3Array, a: StringName, b: StringName) -> float:
	return _j(pose, a).distance_to(_j(pose, b))


func test_rig_has_every_human_joint_and_a_part_for_every_limb_segment() -> void:
	check_eq(Humanoid.JOINTS.size(), 21, "twenty-one joints")
	for joint: StringName in [&"neck", &"shoulder_l", &"elbow_r", &"wrist_l", &"hip_r", &"knee_l", &"ankle_r"]:
		check(Humanoid.JOINTS.has(joint), "joint %s" % joint)
	var parts: Array[StringName] = []
	for part: Array in Humanoid.PARTS:
		parts.append(part[0])
	for wanted: StringName in [&"neck", &"chest", &"belly", &"upper_arm_l", &"forearm_l", &"hand_l",
			&"upper_arm_r", &"forearm_r", &"hand_r", &"thigh_l", &"shin_l", &"foot_l", &"thigh_r", &"shin_r", &"foot_r"]:
		check(parts.has(wanted), "body part %s" % wanted)
	check(Humanoid.BALLS.size() >= 12, "a visible ball at shoulders, elbows, wrists, hips, knees, ankles")


func test_every_pose_keeps_limb_lengths() -> void:
	var rest: PackedVector3Array = Humanoid.rest_local()
	var bones: Array = [[&"hip_l", &"knee_l"], [&"knee_l", &"ankle_l"], [&"hip_r", &"knee_r"], [&"knee_r", &"ankle_r"],
		[&"shoulder_l", &"elbow_l"], [&"elbow_l", &"wrist_l"], [&"shoulder_r", &"elbow_r"], [&"elbow_r", &"wrist_r"],
		[&"neck", &"head"], [&"pelvis", &"spine"]]
	for phase: float in [0.0, 0.8, 1.6, 2.4, 3.2, 4.0, 5.0, 6.0]:
		for setting: Array in [[1.0, 0.0, 0.0, 0.0], [0.5, 1.0, 0.0, 0.0], [0.0, 1.0, 1.0, 0.0], [0.3, 0.0, 0.0, 1.0]]:
			var p: PackedVector3Array = Humanoid.pose(phase, setting[0], setting[1], setting[2], setting[3])
			for bone: Array in bones:
				check_near(_len(p, bone[0], bone[1]), _len(rest, bone[0], bone[1]), 0.002,
					"%s-%s at phase %.1f %s" % [bone[0], bone[1], phase, str(setting)])


func test_knees_only_bend_backwards_and_feet_stay_on_the_ground() -> void:
	for step: int in 32:
		var phase: float = TAU * step / 32.0
		var p: PackedVector3Array = Humanoid.pose(phase, 1.0, 0.0, 0.0, 0.0)
		for side: String in ["l", "r"]:
			var hip: Vector3 = _j(p, StringName("hip_" + side))
			var knee: Vector3 = _j(p, StringName("knee_" + side))
			var ankle: Vector3 = _j(p, StringName("ankle_" + side))
			# The knee sits in front of (or on) the straight line from hip to ankle. -Z is forward.
			var on_line: Vector3 = hip.lerp(ankle, 0.5)
			check(knee.z <= on_line.z + 0.002, "knee_%s bends the wrong way at phase %.2f" % [side, phase])
		var lowest: float = minf(_j(p, &"ankle_l").y, _j(p, &"ankle_r").y)
		check_near(lowest, Humanoid.REST[&"ankle_l"].y, 0.002, "lower foot planted at phase %.2f" % phase)


func test_walking_moves_the_legs_and_swings_the_arms_opposite() -> void:
	var a: PackedVector3Array = Humanoid.pose(PI * 0.5, 1.0, 0.0, 0.0, 0.0)
	check(_j(a, &"knee_l").z < _j(a, &"knee_r").z - 0.2, "left leg forward, right leg back")
	check(_j(a, &"wrist_r").z < _j(a, &"wrist_l").z - 0.1, "right arm forward with the left leg")
	var still: PackedVector3Array = Humanoid.pose(PI * 0.5, 0.0, 0.0, 0.0, 0.0)
	check(absf(_j(still, &"knee_l").z - _j(still, &"knee_r").z) < 0.01, "standing still the legs are together")


func test_aiming_raises_the_arm_forward_and_two_hands_meet() -> void:
	var one: PackedVector3Array = Humanoid.pose(0.0, 0.0, 1.0, 0.0, 0.0)
	check(_j(one, &"hand_r").z < -0.5, "right hand out in front")
	check(_j(one, &"hand_r").y > 1.2, "at shoulder height")
	check(_j(one, &"hand_l").y < 1.0, "left hand still down")
	var two: PackedVector3Array = Humanoid.pose(0.0, 0.0, 1.0, 1.0, 0.0)
	check(_j(two, &"hand_l").z < -0.35, "left hand forward too")
	check(_j(two, &"hand_l").x > -0.12, "and turned in toward the gun (x=%.2f)" % _j(two, &"hand_l").x)


func test_stagger_bends_the_body_back() -> void:
	var hit: PackedVector3Array = Humanoid.pose(0.0, 0.0, 0.0, 0.0, 1.0)
	check(_j(hit, &"head").z > 0.25, "head thrown back (z=%.2f)" % _j(hit, &"head").z)


func test_dude_is_drawn_with_the_rig_and_holds_its_gun_in_the_hand() -> void:
	var dude: PinkDude = preload("res://enemies/pink_dude.tscn").instantiate()
	world.add_child(dude)
	dude.sense_override = true
	check(dude.skin != null and dude.joints.size() == 21, "dude has a 21-joint body")
	check(dude.weapon.get_parent() == dude.hand_anchor, "pistol is parented to the hand")
	dude.aiming = true
	for i: int in 40:
		dude._animate(1.0 / 60.0)
	var hand: Vector3 = dude.joints[Humanoid.index_of(&"hand_r")]
	check(dude.weapon.global_position.distance_to(hand) < 0.12, "gun follows the raised hand")
	var pointing: Vector3 = -dude.weapon.global_transform.basis.z.normalized()
	check(pointing.dot(-dude.global_transform.basis.z) > 0.9, "and points where he faces")


func test_dead_dude_goes_limp_in_place_then_shatters() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var dude: PinkDude = get_tree().get_first_node_in_group(&"enemies") as PinkDude
	var pelvis_before: Vector3 = dude.joints[Humanoid.index_of(&"pelvis")]
	dude.on_bullet_hit(null, dude.global_position, Vector3.UP)
	var bodies: Array[Node] = get_tree().get_nodes_in_group(&"ragdolls")
	check_eq(bodies.size(), 1, "a ragdoll took his place")
	var body: Ragdoll = bodies[0]
	check(body.use_world_time, "it falls on world time, in slow motion with everything else")
	check(body.point(&"pelvis").distance_to(pelvis_before) < 0.05, "starting from the pose he died in")
	check_eq(body.material, Mats.pink(), "and it is pink")
	await wait_physics(int(T.dude_ragdoll_shatter * 60.0) + 20)
	check(not is_instance_valid(body), "then it bursts into shards")


func test_slow_world_means_a_slow_fall() -> void:
	check(Game.load_level("test_doors"), "level loads")
	await wait_physics(3)
	var dude: PinkDude = get_tree().get_first_node_in_group(&"enemies") as PinkDude
	TimeManager.override_scale = T.min_scale
	await wait_frames(2)
	dude.on_bullet_hit(null, dude.global_position, Vector3.UP)
	var body: Ragdoll = get_tree().get_first_node_in_group(&"ragdolls") as Ragdoll
	var head_before: float = body.point(&"head").y
	await wait_physics(30)
	check(head_before - body.point(&"head").y < 0.08, "half a second of real time barely moves it while the world crawls")
	check(is_instance_valid(body), "and it has not shattered yet")


func test_player_has_a_body_with_walking_legs() -> void:
	check(Game.load_level("test_room"), "level loads")
	await wait_physics(3)
	var player: Player = Game.player
	check(player.body != null and player.body_joints.size() == 21, "player has the same 21-joint body")
	var standing: float = absf(player.body_joints[Humanoid.index_of(&"knee_l")].distance_to(player.body_joints[Humanoid.index_of(&"knee_r")]))
	Input.action_press(&"move_forward")
	var widest: float = 0.0
	for i: int in 40:
		await wait_physics(1)
		widest = maxf(widest, player.body_joints[Humanoid.index_of(&"knee_l")].distance_to(player.body_joints[Humanoid.index_of(&"knee_r")]))
	Input.action_release(&"move_forward")
	check(widest > standing + 0.2, "legs stride when walking (%.2f vs %.2f)" % [widest, standing])
