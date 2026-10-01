extends Node
## Keeps a LAN game in step. The host simulates the whole floor and sends out what everything
## is doing; everybody else sends up what they are pressing and draws what comes back.
##
## That split is not an implementation detail, it is the only one that works here: the world
## moves when a player moves, and "a player" has to mean all of them, which can only be decided
## in one place. The host folds every player's movement into `TimeManager`.
##
## Nothing here is clever about bandwidth. A floor holds a few dozen dudes, a LAN has plenty of
## room, and a snapshot of everybody twenty times a second is a few kilobytes.

const RATE: float = 1.0 / 20.0

## The other players, by peer id, as they are drawn on this machine.
var avatars: Dictionary[int, Player] = {}

var _clock: float = 0.0
var _my_look := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Net.player_left.connect(_drop_avatar)


func _unhandled_input(event: InputEvent) -> void:
	# A joined player's mouse is sent up as a turn; the host does the turning.
	if Net.role != Net.Role.JOINED or not (event is InputEventMouseMotion):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion: InputEventMouseMotion = event
	var sens: float = Settings.mouse_sensitivity
	_my_look += Vector2(-motion.relative.x * sens, -motion.relative.y * sens)


func _physics_process(delta: float) -> void:
	if not Net.is_online():
		return
	_clock += delta
	if Net.role == Net.Role.JOINED:
		_send_what_i_am_doing()
		return
	if _clock < RATE:
		return
	_clock = 0.0
	_send_the_world()


# ---------------------------------------------------------------- the joiner's end

func _send_what_i_am_doing() -> void:
	var move: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var buttons: Dictionary = {}
	for action: StringName in [&"primary", &"secondary", &"throw_item", &"kick", &"interact",
			&"use_shield", &"jump"]:
		if Input.is_action_just_pressed(action):
			buttons[action] = true
	var look: Vector2 = _my_look
	_my_look = Vector2.ZERO
	rpc_id(1, &"_took_input", move, deg_to_rad(look.x), deg_to_rad(look.y), buttons)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _took_input(move: Vector2, yaw: float, pitch: float, buttons: Dictionary) -> void:
	if Net.role != Net.Role.HOSTING:
		return
	var who: int = multiplayer.get_remote_sender_id()
	var avatar: Player = avatars.get(who)
	if avatar == null or not is_instance_valid(avatar):
		return
	avatar.relayed = buttons.duplicate()
	avatar.relayed["move"] = move
	avatar.use_relayed = true
	if absf(yaw) > 0.00001 or absf(pitch) > 0.00001:
		avatar.turn_by(yaw, pitch)


# ---------------------------------------------------------------- the host's end

## Everything a joiner needs to draw the floor: where the players are, where the dudes are, and
## which of them are still standing.
func _send_the_world() -> void:
	var people: Array = []
	for id: int in avatars:
		var avatar: Player = avatars[id]
		if is_instance_valid(avatar):
			people.append([id, avatar.global_position, avatar.rotation.y, avatar.alive])
	if Game.player != null and is_instance_valid(Game.player):
		people.append([1, Game.player.global_position, Game.player.rotation.y, Game.player.alive])
	var dudes: Array = []
	var index: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var dude: PinkDude = node as PinkDude
		if dude != null:
			dudes.append([index, dude.global_position, dude.rotation.y, dude.alive])
		index += 1
	rpc(&"_world_is", Game.level_name, people, dudes, TimeManager.world_scale)


@rpc("authority", "call_remote", "unreliable_ordered")
func _world_is(level: String, people: Array, dudes: Array, scale: float) -> void:
	if Net.role != Net.Role.JOINED:
		return
	if Game.level_name != level:
		Game.load_level(level)      # the host moved on: follow it
		return
	TimeManager.override_scale = scale
	for row: Array in people:
		var id: int = row[0]
		if id == multiplayer.get_unique_id():
			# My own player: the host owns where I am, since it owns the walls I bumped into.
			if Game.player != null and is_instance_valid(Game.player):
				Game.player.global_position = Game.player.global_position.lerp(row[1], 0.5)
			continue
		var avatar: Player = _avatar_for(id)
		if avatar != null:
			avatar.global_position = avatar.global_position.lerp(row[1], 0.5)
			avatar.rotation.y = row[2]
	var here: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	for row: Array in dudes:
		var at: int = row[0]
		if at >= here.size():
			continue
		var dude: PinkDude = here[at] as PinkDude
		if dude == null:
			continue
		dude.sense_override = true      # the host decides what he is doing
		dude.global_position = dude.global_position.lerp(row[1], 0.5)
		dude.rotation.y = row[2]
		if not bool(row[3]) and dude.alive:
			dude.die()


# ---------------------------------------------------------------- bodies for the others

## A player for somebody else, on whichever machine needs to draw one.
func _avatar_for(id: int) -> Player:
	if avatars.has(id) and is_instance_valid(avatars[id]):
		return avatars[id]
	if Game.level == null:
		return null
	var avatar := Player.new()
	avatar.name = "Player%d" % id
	avatar.remote = true
	Game.entities_root(self).add_child(avatar)
	avatar.global_position = Game.data.cell_center(Game.data.player_start, 0.05) if Game.data != null else Vector3.ZERO
	# Somebody else's player is a body you can see, not a pair of hands.
	avatar.set_third_person(true)
	avatars[id] = avatar
	return avatar


func _drop_avatar(id: int) -> void:
	if avatars.has(id):
		if is_instance_valid(avatars[id]):
			avatars[id].queue_free()
		avatars.erase(id)


## The host makes a body for somebody who has just joined, and starts relaying their input to it.
func welcome(id: int) -> void:
	if Net.role != Net.Role.HOSTING:
		return
	var avatar: Player = _avatar_for(id)
	if avatar != null:
		avatar.remote = false
		avatar.use_relayed = true
