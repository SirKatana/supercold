class_name HelperVoice
extends Node3D
## What the helper says: a speech bubble over his head, and the same line spoken aloud.
##
## The voice is pre-rendered. Every line in allies/voice_lines.json was synthesized once with
## Piper, an open-source neural TTS, using the CC0 voice en_US-joe (tools/make_voice.py), and
## ships as allies/voice/<id>.ogg. No API, no key, nothing online at runtime. Callouts that
## change every time ("Rifleman, three o'clock, ten metres!") are chained from short clips.
## If a clip is missing, the system text-to-speech voice reads the line instead.
##
## Lines have a priority. A higher one interrupts, a lower one waits its turn or is dropped,
## so he never talks over himself and never spams.

enum Priority { CHATTER, CALLOUT, IMPORTANT }

const BUBBLE_HEIGHT: float = 2.25
const PIXEL: float = 0.0042
const WRAP_PX: float = 470.0
const MIN_GAP: float = 1.6

## Off in tests and headless runs. The bubble logic still runs.
static var tts_enabled: bool = true

static var _lines: Dictionary = {}
static var _clips: Dictionary[StringName, AudioStream] = {}


## The text of a line from voice_lines.json.
static func line(id: StringName) -> String:
	if _lines.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://allies/voice_lines.json"))
		if parsed is Dictionary:
			_lines = parsed
	return str(_lines.get(String(id), String(id)))


static func clip(id: StringName) -> AudioStream:
	if not _clips.has(id):
		var path: String = "res://allies/voice/%s.ogg" % id
		_clips[id] = load(path) if ResourceLoader.exists(path) else null
	return _clips[id]

var last_line: String = ""
var history: PackedStringArray = []

var _label: Label3D
var _panel: MeshInstance3D
var _border: MeshInstance3D
var _show_left: float = 0.0
var _quiet_left: float = 0.0
var _current_priority: int = -1
var _voice_id: String = ""
var _voice_checked: bool = false
var _speaker: AudioStreamPlayer
var _queue: Array[AudioStream] = []


func _ready() -> void:
	position.y = BUBBLE_HEIGHT
	_border = _quad(Color(0.05, 0.05, 0.06, 0.95), -2)
	_panel = _quad(Color(1, 1, 1, 0.96), -1)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.shaded = false
	_label.pixel_size = PIXEL
	_label.font_size = 38
	_label.outline_size = 0
	_label.modulate = Color(0.05, 0.05, 0.06)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = WRAP_PX
	_label.render_priority = 3
	add_child(_label)
	# In your ear like a radio, at true pitch whatever the world clock is doing.
	_speaker = AudioStreamPlayer.new()
	_speaker.volume_db = 2.0
	_speaker.finished.connect(_play_next)
	add_child(_speaker)
	_set_visible(false)


func _quad(color: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.no_depth_test = true
	material.render_priority = priority
	mesh.material = material
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _set_visible(shown: bool) -> void:
	_label.visible = shown
	_panel.visible = shown
	_border.visible = shown


func is_talking() -> bool:
	return _show_left > 0.0


## Says a line. Returns false if it was dropped because something as or more important is
## still being said, or because he spoke a moment ago.
## Says one recorded line by its id.
func say_line(id: StringName, priority: int = Priority.CHATTER) -> bool:
	return say(line(id), priority, [id])


func say(text: String, priority: int = Priority.CHATTER, clip_ids: Array[StringName] = []) -> bool:
	if is_talking() and priority <= _current_priority:
		return false
	if not is_talking() and _quiet_left > 0.0 and priority == Priority.CHATTER:
		return false
	last_line = text
	history.append(text)
	_current_priority = priority
	_label.text = text
	var size: Vector2 = ThemeDB.fallback_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, WRAP_PX, 38)
	var w: float = minf(size.x, WRAP_PX) * PIXEL + 0.22
	var h: float = size.y * PIXEL + 0.16
	_panel.scale = Vector3(w, h, 1)
	_border.scale = Vector3(w + 0.05, h + 0.05, 1)
	_set_visible(true)
	# Long enough to read, and about as long as the voice takes to say it.
	_show_left = clampf(1.4 + text.length() * 0.065, 1.8, 5.5)
	_speak(text, priority, clip_ids)
	return true


func _pick_voice() -> void:
	_voice_checked = true
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices: Array[Dictionary] = DisplayServer.tts_get_voices()
	var fallback: String = ""
	for v: Dictionary in voices:
		var id: String = v.get("id", "")
		var language: String = v.get("language", "")
		if id == "English (America)" or id == "English (Great Britain)":
			_voice_id = id
			return
		if fallback == "" and language.begins_with("en"):
			fallback = id
	_voice_id = fallback


func _speak(text: String, priority: int, clip_ids: Array[StringName]) -> void:
	if not tts_enabled or Settings.volume <= 0.001:
		return
	var streams: Array[AudioStream] = []
	for id: StringName in clip_ids:
		var stream: AudioStream = clip(id)
		if stream == null:
			streams.clear()
			break
		streams.append(stream)
	if not streams.is_empty():
		_speaker.stop()
		_queue = streams
		_play_next()
		return
	_speak_with_system_voice(text, priority)


func _play_next() -> void:
	if _queue.is_empty():
		return
	_speaker.stream = _queue.pop_front()
	_speaker.play()


## Fallback only: a line with no recorded clip.
func _speak_with_system_voice(text: String, priority: int) -> void:
	if not _voice_checked:
		_pick_voice()
	if _voice_id == "":
		return
	var spoken: String = text.replace("'", "").replace(":", ",").replace("!", ".")
	DisplayServer.tts_speak(spoken, _voice_id, int(clampf(Settings.volume, 0.0, 1.0) * 100.0), 1.0, 1.0, 0,
		priority >= Priority.CALLOUT)


func _process(delta: float) -> void:
	# Real time: a sentence takes as long to say whether or not the world is crawling.
	_quiet_left = maxf(0.0, _quiet_left - delta)
	if _show_left > 0.0:
		_show_left -= delta
		if _show_left <= 0.0:
			_set_visible(false)
			_current_priority = -1
			_quiet_left = MIN_GAP


func shut_up() -> void:
	_show_left = 0.0
	_set_visible(false)
	_queue.clear()
	_speaker.stop()
	if tts_enabled and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()


func _exit_tree() -> void:
	if tts_enabled and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()


# ---------------------------------------------------------------- what to say

## "3 o'clock" for something to the listener's right, "12 o'clock" for dead ahead.
static func clock_direction(listener: Transform3D, point: Vector3) -> int:
	var local: Vector3 = listener.basis.orthonormalized().inverse() * (point - listener.origin)
	var angle: float = atan2(local.x, -local.z)      # 0 ahead, positive to the right
	var hour: int = int(roundf(angle / (TAU / 12.0)))
	hour = ((hour % 12) + 12) % 12
	return 12 if hour == 0 else hour


## A map reference like "C4": columns are letters, rows are numbers, four cells to a sector.
static func sector(data: LevelData, point: Vector3) -> String:
	if data == null:
		return ""
	var col: int = clampi(int(point.x / data.cell_size) / 4, 0, 25)
	var row: int = clampi(int(point.z / data.cell_size) / 4, 0, 98)
	return "%s%d" % [char(65 + col), row + 1]


## The clip id for a kind of dude. The spoken name and the bubble name come from the same line.
static func name_id(dude: PinkDude) -> StringName:
	if dude.has_method(&"voice_name_id"):
		return dude.call(&"voice_name_id")
	if dude is Director:
		return &"name_director"
	if dude is ShieldDude:
		return &"name_shield"
	if not dude.has_weapon():
		return &"name_brawler"
	if dude.weapon is Rifle:
		return &"name_rifle"
	if dude.weapon is Shotgun:
		return &"name_shotgun"
	if dude.weapon is SniperRifle:
		return &"name_sniper"
	return &"name_pink"


## The clips that speak a callout: who, which way, how far. The sector is bubble only.
static func callout_clips(listener: Transform3D, dude: PinkDude) -> Array[StringName]:
	var metres: int = int(roundf(listener.origin.distance_to(dude.global_position)))
	var out: Array[StringName] = [name_id(dude), StringName("clock_%d" % clock_direction(listener, dude.global_position)),
		StringName("dist_%d" % metres) if metres >= 1 and metres <= 40 else &"dist_far"]
	if dude is ShieldDude:
		out.append(&"aim_glass")
	return out


static func name_of(dude: PinkDude) -> String:
	if dude.has_method(&"voice_name_id"):
		return line(dude.call(&"voice_name_id")).trim_suffix(",")
	if dude is Director:
		return "The Director"
	if dude is ShieldDude:
		return "Shield trooper"
	if not dude.has_weapon():
		return "Brawler"
	if dude.weapon is Rifle:
		return "Rifleman"
	if dude.weapon is Shotgun:
		return "Shotgunner"
	return "Pink dude"


## The coordinates he shouts when he spots someone, from the player's point of view.
static func callout(listener: Transform3D, dude: PinkDude, data: LevelData) -> String:
	var hour: int = clock_direction(listener, dude.global_position)
	var metres: int = int(roundf(listener.origin.distance_to(dude.global_position)))
	var where: String = sector(data, dude.global_position)
	var line: String = "%s, %d o'clock, %d metres" % [name_of(dude), hour, metres]
	if where != "":
		line += ", sector %s" % where
	line += "!"
	if dude is ShieldDude:
		line += " Aim for the glass!"
	return line


static func pick(lines: Array[String]) -> String:
	return lines[randi() % lines.size()]
