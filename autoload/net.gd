extends Node
## LAN play. One machine hosts, the others join with a six-character code, and everybody has to
## be on the same network -- there is no server anywhere and nothing leaves the building.
##
## The code is the host's own address, packed: the last two numbers of its LAN address and the
## port's offset, in base 32. That means a code can be typed in and dialled straight away with
## no lookup at all, and the broadcast below is only there so a host that moved to a different
## subnet can still be found.
##
## The host simulates everything. Enemies, bullets, doors, time: all of it runs there, and the
## joiners send their input up and get the world back. That is the only arrangement that works
## for a game whose whole rule is that the world moves when *a* player moves.

signal state_changed
signal player_joined(id: int)
signal player_left(id: int)
signal failed(why: String)

const PORT_BASE: int = 27800
const MAX_PLAYERS: int = 4
## Base 32 without the letters that get misread when somebody reads a code down the room.
const ALPHABET: String = "0123456789ABCDEFGHJKLMNPQRSTUVWX"

enum Role { OFF, HOSTING, JOINING, JOINED }

var role: Role = Role.OFF
var code: String = ""
## Everybody in the game, by peer id. The host is 1.
var players: Dictionary[int, Dictionary] = {}

var _peer: ENetMultiplayerPeer = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _give_up("could not reach that code"))
	multiplayer.server_disconnected.connect(func() -> void: _give_up("the host closed the game"))


func is_online() -> bool:
	return role == Role.HOSTING or role == Role.JOINED


## True on the machine that owns the simulation. A single-player game is its own host.
func is_host() -> bool:
	return role != Role.JOINED


# ---------------------------------------------------------------- codes

## This machine's address on the LAN, or "" if it is not on one.
func lan_address() -> String:
	for address: String in IP.get_local_addresses():
		if address.begins_with("127.") or address.contains(":"):
			continue
		if address.begins_with("10.") or address.begins_with("192.168.") or _is_172_private(address):
			return address
	return ""


func _is_172_private(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var second: int = int(address.split(".")[1])
	return second >= 16 and second <= 31


## Packs an address and port into six characters. Only the last two numbers of the address go
## in: everybody on one network shares the first two.
static func pack(address: String, port: int) -> String:
	var bits: PackedStringArray = address.split(".")
	if bits.size() != 4:
		return ""
	var value: int = int(bits[2]) * 65536 + int(bits[3]) * 256 + clampi(port - PORT_BASE, 0, 255)
	var out: String = ""
	for i: int in 6:
		out = ALPHABET[value % 32] + out
		value /= 32
	return out


## Turns a code back into the two numbers and the port. Returns [] if it is not a code.
static func unpack(from_code: String) -> Array:
	var tidy: String = from_code.strip_edges().to_upper()
	if tidy.length() != 6:
		return []
	var value: int = 0
	for i: int in tidy.length():
		var digit: int = ALPHABET.find(tidy[i])
		if digit < 0:
			return []
		value = value * 32 + digit
	var third: int = (value / 65536) % 256
	var fourth: int = (value / 256) % 256
	return [third, fourth, PORT_BASE + value % 256]


# ---------------------------------------------------------------- hosting and joining

## Opens this machine up and returns the code to read out, or "" if it could not.
func host() -> String:
	close()
	var address: String = lan_address()
	if address == "":
		failed.emit("this machine is not on a network")
		return ""
	_peer = ENetMultiplayerPeer.new()
	var port: int = PORT_BASE
	var started: int = _peer.create_server(port, MAX_PLAYERS - 1)
	while started != OK and port < PORT_BASE + 32:
		port += 1
		started = _peer.create_server(port, MAX_PLAYERS - 1)
	if started != OK:
		failed.emit("could not open a port")
		_peer = null
		return ""
	multiplayer.multiplayer_peer = _peer
	role = Role.HOSTING
	code = pack(address, port)
	players = {1: {"name": "HOST", "ready": true}}
	state_changed.emit()
	return code


## Dials a code. The first two numbers of the address come from this machine, because the whole
## point of a LAN game is that both ends are on the same one.
func join(with_code: String) -> bool:
	close()
	var parts: Array = unpack(with_code)
	if parts.is_empty():
		failed.emit("that is not a code")
		return false
	var mine: String = lan_address()
	if mine == "":
		failed.emit("this machine is not on a network")
		return false
	var head: PackedStringArray = mine.split(".")
	var address: String = "%s.%s.%d.%d" % [head[0], head[1], parts[0], parts[1]]
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_client(address, parts[2]) != OK:
		failed.emit("could not dial %s" % address)
		_peer = null
		return false
	multiplayer.multiplayer_peer = _peer
	role = Role.JOINING
	code = with_code.strip_edges().to_upper()
	state_changed.emit()
	return true


func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	role = Role.OFF
	code = ""
	players.clear()
	state_changed.emit()


func _give_up(why: String) -> void:
	failed.emit(why)
	close()


func _on_connected() -> void:
	role = Role.JOINED
	players[multiplayer.get_unique_id()] = {"name": "YOU", "ready": true}
	state_changed.emit()


func _on_peer_connected(id: int) -> void:
	players[id] = {"name": "PLAYER %d" % id, "ready": true}
	if role == Role.HOSTING:
		NetSync.welcome(id)
	player_joined.emit(id)
	state_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_left.emit(id)
	state_changed.emit()
