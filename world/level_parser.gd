class_name LevelParser
extends RefCounted
## Turns an ASCII grid plus optional JSON sidecar into LevelData.
##
## `#` wall  `.` floor  ` ` void  `D` door  `G` glass  `P` player  `X` exit
## `H` shield trooper  `g` gas barrel
## `a` pistol dude  `R` rifle dude  `S` shotgun dude  `u` unarmed dude  `K` AK-47  `T` shotgun
##  `B` boss  `w` wave point  `t` trigger
## `r` wall breaker  `p` pistol  `b` bottle  `m` mug  `k` keyboard  `l` stapler
## `c` desk  `s` server rack  `o` pillar (full height cover)

const PICKUP_KINDS: Dictionary[String, StringName] = {
	"p": &"pistol", "b": &"bottle", "m": &"mug", "k": &"keyboard", "l": &"stapler", "r": &"ram", "K": &"rifle", "T": &"shotgun", "g": &"barrel",
}
const PROP_KINDS: Dictionary[String, StringName] = {"c": &"desk", "s": &"rack", "o": &"pillar"}
const KNOWN: String = "#. DGPXauBwtpbmklcsorRSKTHg"


static func load_level(level_name: String) -> LevelData:
	var base: String = "res://levels/%s" % level_name
	var text: String = FileAccess.get_file_as_string(base + ".txt")
	var json_text: String = ""
	if FileAccess.file_exists(base + ".json"):
		json_text = FileAccess.get_file_as_string(base + ".json")
	var data: LevelData = parse(text, json_text)
	data.level_name = level_name
	if text.is_empty():
		data.errors.append("level file missing or empty: %s.txt" % base)
	return data


static func parse(text: String, json_text: String = "") -> LevelData:
	var data := LevelData.new()
	data.cell_size = (preload("res://data/tuning.tres") as Tuning).cell_size
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	for line: String in lines:
		data.width = maxi(data.width, line.length())
	data.height = lines.size()
	for line: String in lines:
		data.rows.append(line.rpad(data.width, " "))

	for y: int in data.height:
		for x: int in data.width:
			var c: String = data.rows[y][x]
			var cell := Vector2i(x, y)
			if not KNOWN.contains(c):
				data.errors.append("unknown character '%s' at %d,%d" % [c, x, y])
			elif c == "P":
				if data.player_start.x >= 0:
					data.errors.append("more than one player start")
				data.player_start = cell
			elif c == "X":
				if data.exit_cell.x >= 0:
					data.errors.append("more than one exit")
				data.exit_cell = cell
			elif c == "B":
				data.boss_cell = cell
			elif c == "a" or c == "u" or c == "R" or c == "S" or c == "H":
				var gun: StringName = &"rifle" if c == "R" else (&"shotgun" if c == "S" else (&"shield" if c == "H" else &"pistol"))
				data.spawns.append({"cell": cell, "armed": c != "u", "weapon": gun})
			elif c == "w":
				data.wave_points.append(cell)
			elif c == "t":
				data.triggers.append(cell)
			elif c == "D":
				data.doors.append({"cell": cell, "along_x": _runs_along_x(data, cell)})
			elif c == "G":
				data.glass.append({"cell": cell, "along_x": _runs_along_x(data, cell)})
			elif PICKUP_KINDS.has(c):
				data.pickups.append({"cell": cell, "kind": PICKUP_KINDS[c]})
			elif PROP_KINDS.has(c):
				data.props.append({"cell": cell, "kind": PROP_KINDS[c]})

	if data.player_start.x < 0:
		data.errors.append("no player start 'P'")
	if data.exit_cell.x < 0:
		data.errors.append("no exit 'X'")

	if json_text != "":
		var parsed: Variant = JSON.parse_string(json_text)
		if parsed is Dictionary:
			var d: Dictionary = parsed
			data.intro = str(d.get("intro", ""))
			data.open_sky = bool(d.get("open_sky", false))
			data.exit_kind = StringName(str(d.get("exit", "elevator")))
			for w: Variant in d.get("waves", []):
				if w is Dictionary:
					var wd: Dictionary = w
					data.waves.append({
						"after_kills": int(wd.get("after_kills", -1)),
						"on_trigger": bool(wd.get("on_trigger", false)),
						"count": int(wd.get("count", 3)),
						"armed": int(wd.get("armed", 2)),
					})
		else:
			data.errors.append("sidecar json is not an object")
	if data.waves.size() > 0 and data.wave_points.is_empty():
		data.errors.append("waves defined but no 'w' wave points")
	return data


## A door or glass pane spans along X when walls (or more panes) sit to its left and right.
static func _runs_along_x(data: LevelData, cell: Vector2i) -> bool:
	var side: String = "#DG"
	var left: bool = side.contains(data.char_at(cell + Vector2i.LEFT))
	var right: bool = side.contains(data.char_at(cell + Vector2i.RIGHT))
	var up: bool = side.contains(data.char_at(cell + Vector2i.UP))
	var down: bool = side.contains(data.char_at(cell + Vector2i.DOWN))
	if left and right:
		return true
	if up and down:
		return false
	return left or right
