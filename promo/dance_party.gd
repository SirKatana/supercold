extends Node3D
## The SuperCold promo: a dance number on the Can-Can. Not part of the game, never exported.
##
## Rendered offscreen by tools/make_promo.sh with Godot's movie writer at a fixed 30 fps, then
## muxed with promo/out/cancan.wav. Everything is driven by one clock: `out_time` is video time,
## `song_time` is where the music is, and the two differ only by the rate curve in
## promo/timing.json, the same curve tools/make_song.py played the tape through. When the rate
## drops to 0.06 the music crawls and so does everybody except the player. That is the joke,
## and it is also the game.
##
## Stills for checking: `-- --at=17.5 --shot=/tmp/x.png`

const Dancer: GDScript = preload("res://promo/dancer.gd")
const PINK := Color(1.0, 0.176, 0.584)

var timing: Dictionary
var beat: float
var bar: float
var song: Dictionary
var curve: Dictionary
var out_time: float = 0.0
var song_time: float = 0.0
var length: float = 0.0

var player: Node3D
var helpers: Array[Node3D] = []
var line: Array[Node3D] = []
var gunners: Array[Node3D] = []
var recoil: Array[float] = [0.0, 0.0]
var _last_shot_beat: int = -1

var camera: Camera3D
var tiles: Array[StandardMaterial3D] = []
var spots: Array[SpotLight3D] = []
var sign_material: StandardMaterial3D
var ball: Node3D
var ball_home := Vector3(0.0, 5.3, 1.4)
var chain: MeshInstance3D
var caption: Label
var title: Control
var flashes: Array[OmniLight3D] = []
var rounds: Array[Dictionary] = []
var sun: DirectionalLight3D
var ground: StandardMaterial3D
var env: Environment
var _crushed: bool = false
var _shot_path: String = ""
var _frames: int = 0


func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return fallback


func _ready() -> void:
	timing = JSON.parse_string(FileAccess.get_file_as_string("res://promo/timing.json"))
	beat = timing["beat"]
	bar = timing["bar"]
	song = timing["song"]
	curve = timing["curve"]
	length = timing["length"]
	_shot_path = _arg("shot", "")
	HelperVoice.tts_enabled = false
	_build_stage()
	_build_cast()
	_build_overlay()
	# Jump to a moment for a still. The rate curve has to be walked to find the song position.
	var at: float = float(_arg("at", "0"))
	while out_time < at:
		_advance(1.0 / 300.0)
	_update(0.0)


func rate_at(t: float) -> float:
	var f: float = curve["freeze_at"]
	var down: float = curve["down"]
	var hold: float = curve["hold"]
	var up: float = curve["up"]
	var low: float = timing["min_scale"]
	if t < f or t >= f + down + hold + up:
		return 1.0
	if t < f + down:
		return 1.0 + (low - 1.0) * pow((t - f) / down, 0.6)
	if t < f + down + hold:
		return low
	return low + (1.0 - low) * pow((t - f - down - hold) / up, 2.0)


func _advance(delta: float) -> void:
	song_time += rate_at(out_time) * delta
	out_time += delta


func _process(delta: float) -> void:
	_frames += 1
	if _shot_path != "":
		if _frames == 4:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()
		_update(0.0)
		return
	var steps: int = 10
	for i: int in steps:
		_advance(delta / steps)
	_update(delta)
	if out_time >= length:
		get_tree().quit()


# ------------------------------------------------------------------ building

func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	add_child(mi)
	return mi


func _build_stage() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.94, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.92, 1.0)
	env.ambient_light_energy = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 160, 0)
	sun.light_energy = 0.8
	add_child(sun)

	# A dance floor of lit tiles, Saturday night style.
	for ix: int in 12:
		for iz: int in 8:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.92, 0.93, 0.95)
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission = Color.BLACK
			tiles.append(m)
			_box(Vector3(1.16, 0.1, 1.16), Vector3((ix - 5.5) * 1.2, -0.05, (iz - 2.5) * 1.2), m)
	ground = StandardMaterial3D.new()
	ground.albedo_color = Color(0.86, 0.87, 0.9)
	_box(Vector3(60, 0.1, 60), Vector3(0, -0.12, 0), ground)
	_box(Vector3(16, 7.5, 0.3), Vector3(0, 3.7, 7.4), Mats.wall())
	for side: float in [-1.0, 1.0]:
		_box(Vector3(1.6, 0.9, 1.6), Vector3(6.2 * side, 0.45, 1.8), Mats.black())      # gunners' podiums

	sign_material = StandardMaterial3D.new()
	sign_material.albedo_color = PINK
	sign_material.emission_enabled = true
	sign_material.emission = PINK
	for i: int in 2:
		var word := Label3D.new()
		word.text = ["SUPER", "COLD"][i]
		word.font_size = 420
		word.pixel_size = 0.0042
		word.outline_size = 0
		word.modulate = Color(0.06, 0.06, 0.08) if i == 0 else PINK
		word.position = Vector3(0, 5.35 - i * 1.75, 7.2)
		word.rotation.y = PI
		word.shaded = false
		word.name = "Sign%d" % i
		add_child(word)

	# The disco ball, on a chain somebody is going to regret shooting at.
	ball = Node3D.new()
	ball.position = ball_home
	add_child(ball)
	var sphere := SphereMesh.new()
	sphere.radius = 0.62
	sphere.height = 1.24
	sphere.radial_segments = 14
	sphere.rings = 8
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color(0.85, 0.88, 0.95)
	mirror.metallic = 0.4
	mirror.roughness = 0.2
	mirror.emission_enabled = true
	mirror.emission = Color(0.55, 0.6, 0.75)
	var ball_mesh := MeshInstance3D.new()
	ball_mesh.mesh = sphere
	ball_mesh.material_override = mirror
	ball.add_child(ball_mesh)
	# Facets: little bright squares all over it.
	var facet := BoxMesh.new()
	facet.size = Vector3(0.11, 0.11, 0.02)
	var bright := StandardMaterial3D.new()
	bright.albedo_color = Color.WHITE
	bright.emission_enabled = true
	bright.emission = Color(1.6, 1.6, 1.8)
	for ring: int in 7:
		var lat: float = -1.2 + ring * 0.4
		var count: int = int(maxf(4.0, 16.0 * cos(lat)))
		for k: int in count:
			var lon: float = TAU * k / count + ring * 0.3
			var normal := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var f := MeshInstance3D.new()
			f.mesh = facet
			f.material_override = bright
			f.position = normal * 0.625
			ball.add_child(f)
			f.look_at(ball.global_position + normal * 2.0, Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.025
	rod.height = 2.2
	chain = MeshInstance3D.new()
	chain.mesh = rod
	chain.material_override = Mats.steel()
	chain.position = ball_home + Vector3(0, 1.7, 0)
	add_child(chain)

	for i: int in 4:
		var spot := SpotLight3D.new()
		spot.spot_angle = 24.0
		spot.spot_range = 16.0
		spot.light_energy = 0.0
		spot.position = Vector3(0, 6.4, 1.2)
		add_child(spot)
		spots.append(spot)
	for i: int in 2:
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.8, 0.5)
		flash.omni_range = 5.0
		flash.light_energy = 0.0
		add_child(flash)
		flashes.append(flash)

	camera = Camera3D.new()
	camera.fov = 52.0
	camera.current = true
	add_child(camera)


func _dancer(material: Material, at: Vector3, scale_factor: float = 1.0, mirrored: bool = false) -> Node3D:
	var d: Node3D = Dancer.new()
	add_child(d)
	d.position = at
	d.call(&"setup", material, scale_factor, true)
	d.set(&"mirrored", mirrored)
	return d


func _build_cast() -> void:
	player = _dancer(Mats.black(), Vector3(0, 0, -1.0), 1.04)
	helpers.append(_dancer(Mats.helper_red(), Vector3(-1.9, 0, 0.5)))
	helpers.append(_dancer(Mats.helper_red(), Vector3(1.9, 0, 0.5), 1.0, true))
	for i: int in 5:
		line.append(_dancer(Mats.pink(), Vector3((i - 2) * 1.55, 0, 3.2)))
	for i: int in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var g: Node3D = _dancer(Mats.pink(), Vector3(6.2 * side, 0.9, 1.8), 1.0, i == 0)
		g.rotation.y = -0.35 * side
		gunners.append(g)
		var gun: Node3D = Rifle.create() if i == 0 else Shotgun.create()
		g.call(&"hold", gun)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption.position.y -= 110
	caption.add_theme_font_size_override(&"font_size", 40)
	caption.add_theme_color_override(&"font_color", Color.WHITE)
	caption.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.07))
	caption.add_theme_constant_override(&"outline_size", 14)
	layer.add_child(caption)

	title = ColorRect.new()
	(title as ColorRect).color = Color(0.94, 0.95, 0.97)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.modulate.a = 0.0
	layer.add_child(title)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_child(box)
	for row: Array in [["SUPER", 170, Color(0.06, 0.06, 0.08)], ["COLD", 170, PINK], ["TIME MOVES WHEN YOU GROOVE", 34, Color(0.06, 0.06, 0.08)],
			["no pink dudes were harmed. one was.", 22, Color(0.35, 0.36, 0.4)]]:
		var l := Label.new()
		l.text = row[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override(&"font_size", row[1])
		l.add_theme_color_override(&"font_color", row[2])
		box.add_child(l)


# ------------------------------------------------------------------ the show

func _update(delta: float) -> void:
	var rate: float = rate_at(out_time)
	TimeManager.override_scale = rate
	var beats: float = (song_time - float(song["a1"])) / beat      # 0 at the first note of the tune
	var a1: float = song["a1"]
	var a2: float = song["a2"]
	var a3: float = song["a3"]
	var a4: float = song["a4"]
	var finale: float = song["end"]
	var freeze_start: float = curve["freeze_at"]
	var freeze_end: float = freeze_start + float(curve["down"]) + float(curve["hold"]) + float(curve["up"])
	var frozen: bool = out_time >= freeze_start and out_time < freeze_end
	var started: float = clampf((song_time - a1) / 0.25, 0.0, 1.0)
	var crash_at: float = finale + beat * 2.0          # the last CHA, in song time
	var after: float = song_time - crash_at

	_lights(beats, started, after)

	# --- who does what
	var line_move: StringName = &"cancan"
	var helper_move: StringName = &"disco"
	var player_move: StringName = &"floss"
	if song_time >= a3 + beat * 2.2 and song_time < a3 + bar * 4.0:
		line_move = &"wave"; helper_move = &"wave"; player_move = &"wave"
	elif song_time >= a2 + bar * 4.0 and song_time < a3:
		helper_move = &"wave"; player_move = &"disco"
	elif song_time >= a4 + bar * 4.0:
		player_move = &"disco"; helper_move = &"floss"
	var closing: float = clampf((song_time - finale) / (beat * 0.6), 0.0, 1.0)

	for i: int in line.size():
		_perform(line[i], line_move, beats, started, closing, after, 0.10 * i)
	for h: Node3D in helpers:
		_perform(h, helper_move, beats, started, closing, after, 0.2)

	# The player is the only one who lives on real time. When he stops, the world stops.
	if song_time < a1:
		player.call(&"dance", &"tap", out_time / beat, 1.0)
	elif frozen:
		var into: float = out_time - freeze_start
		var hold_end: float = float(curve["down"]) + float(curve["hold"])
		if into < 1.3:
			player.call(&"dance", &"still", out_time, 1.0)
		elif into < hold_end - 1.1:
			player.call(&"dance", &"shrug", 0.0, 1.0, clampf((into - 1.3) / 0.35, 0.0, 1.0) * clampf((hold_end - 1.1 - into) / 0.3, 0.0, 1.0))
		else:
			player.call(&"dance", &"shades", 0.0, 1.0, clampf((into - (hold_end - 1.1)) / 0.3, 0.0, 1.0) * clampf((freeze_end - 0.25 - into - freeze_start + freeze_start) / 0.3, 0.0, 1.0))
	else:
		_perform(player, player_move, beats, started, closing, after, 0.0)

	# --- the rhythm section: one shot a beat, left on the even beats, right on the odd
	var shooting: bool = song_time >= a1 and song_time < finale + beat * 1.2
	var this_beat: int = int(floor(beats))
	if shooting and this_beat != _last_shot_beat and delta > 0.0:
		_last_shot_beat = this_beat
		_fire(this_beat % 2, song_time >= a4 + bar * 5.0)
	for i: int in 2:
		recoil[i] = maxf(0.0, recoil[i] - delta * rate * 5.0)
		flashes[i].light_energy = 6.0 * pow(recoil[i], 3.0)
		if gunners[i].visible:
			var still_alive: bool = not (_crushed and i == 1)
			if still_alive:
				if after > 0.4:
					gunners[i].call(&"dance", &"shrug", 0.0, 1.0, clampf((after - 0.9) / 0.35, 0.0, 1.0))
				else:
					gunners[i].call(&"dance", &"gun_up", beats, started, recoil[i])
	_move_rounds(delta * rate)
	_ball(delta, beats, crash_at, after)
	_camera(beats, frozen, freeze_start, freeze_end, after)
	_captions(frozen, freeze_start, after)


func _perform(d: Node3D, move: StringName, beats: float, started: float, closing: float, after: float, lag: float) -> void:
	if after > 0.9:
		# Everybody looks at what is left of him. Then: not our problem.
		d.call(&"dance", &"shrug", 0.0, 1.0, clampf((after - 0.9 - lag) / 0.35, 0.0, 1.0))
	elif closing > 0.0:
		d.call(&"dance", &"fever", beats, 1.0)
	else:
		d.call(&"dance", move, beats, started)


func _fire(who: int, at_the_chain: bool) -> void:
	if _crushed and who == 1:
		return
	recoil[who] = 1.0
	var from: Vector3 = gunners[who].call(&"muzzle")
	flashes[who].position = from
	var target: Vector3 = from + Vector3(0, 9, 0)
	if at_the_chain:
		target = chain.global_position + Vector3(0, 0.4, 0)
		Shatter.burst(self, target, 5, Mats.steel(), Vector3.ONE * 0.05, Vector3(0, -1, 0), 0.05)
	var node := Node3D.new()
	add_child(node)
	var slug := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.035
	capsule.height = 0.16
	slug.mesh = capsule
	slug.material_override = Mats.black()
	slug.rotation.x = PI * 0.5
	node.add_child(slug)
	var trail := MeshInstance3D.new()
	var streak := BoxMesh.new()
	streak.size = Vector3(0.03, 0.03, 1.0)
	trail.mesh = streak
	trail.material_override = sign_material
	trail.position.z = 0.6
	node.add_child(trail)
	node.position = from
	node.look_at(target, Vector3.RIGHT)
	rounds.append({"node": node, "dir": (target - from).normalized(), "left": 1.2 if not at_the_chain else from.distance_to(target) / 14.0})


func _move_rounds(step: float) -> void:
	for r: Dictionary in rounds.duplicate():
		var node: Node3D = r["node"]
		node.position += (r["dir"] as Vector3) * 14.0 * step
		r["left"] = float(r["left"]) - step
		if float(r["left"]) <= 0.0:
			node.queue_free()
			rounds.erase(r)


func _ball(delta: float, beats: float, crash_at: float, after: float) -> void:
	var fall_time: float = 0.95
	var t: float = (song_time - (crash_at - fall_time)) / fall_time
	var target: Vector3 = gunners[1].position + Vector3(0, 1.0, 0)
	if t <= 0.0:
		# Hanging, turning, and in the last bars swinging a little more with every hit.
		var nervous: float = clampf((song_time - (float(song["a4"]) + bar * 5.0)) / (bar * 3.0), 0.0, 1.0)
		ball.position = ball_home + Vector3(sin(beats * 1.7) * 0.25 * nervous, 0, 0)
		ball.rotation.y += delta * 0.8 * rate_at(out_time)
		chain.visible = true
	elif t < 1.0:
		chain.visible = false
		ball.position = ball_home.lerp(target, t) + Vector3(0, 1.6 * sin(PI * t) * (1.0 - t), 0)
		ball.rotation.x += delta * 6.0
	else:
		if not _crushed:
			_crushed = true
			gunners[1].visible = false
			Shatter.burst(self, target, 46, Mats.pink(), Vector3(0.3, 0.8, 0.3), Vector3(0, 2.5, -1.0), 0.17)
			Shatter.burst(self, target, 14, Mats.steel(), Vector3(0.3, 0.3, 0.3), Vector3(0, 3.0, 0), 0.08)
		# It rolls off the podium and away, as if nothing happened.
		var roll: float = minf(after, 3.0)
		ball.position = target + Vector3(-0.2 - roll * 0.9, -0.38 - minf(roll * 1.6, 0.9) + 0.25 * absf(sin(roll * 5.0)) * exp(-roll * 1.4), -roll * 0.7)
		ball.rotation.z += delta * 3.0


func _lights(beats: float, started: float, after: float) -> void:
	# House lights until the tune starts, then the room goes dark and the floor takes over.
	var dark: float = started * (1.0 - clampf((after - 2.2) / 0.5, 0.0, 1.0) * 0.0)
	env.background_color = Color(0.86, 0.88, 0.92).lerp(Color(0.03, 0.03, 0.06), dark)
	ground.albedo_color = Color(0.86, 0.87, 0.9).lerp(Color(0.05, 0.05, 0.07), dark)
	env.ambient_light_energy = lerpf(0.55, 0.28, dark)
	env.glow_intensity = lerpf(0.15, 0.9, dark)      # the white room must not bloom into a blank
	sun.light_energy = lerpf(0.55, 0.12, dark)
	var step: int = int(floor(beats))
	var pulse: float = pow(1.0 - fposmod(beats, 1.0), 2.0)
	for i: int in tiles.size():
		var ix: int = i / 8
		var iz: int = i % 8
		var hue: float = fposmod((ix * 3 + iz * 5 + step * 7) * 0.083, 1.0)
		var lit: bool = (ix + iz + step) % 3 != 0
		var colour := Color.from_hsv(hue, 0.85, 1.0)
		if (ix * 7 + iz * 3 + step) % 5 == 0:
			colour = PINK
		tiles[i].emission = (colour * (0.5 + 1.3 * pulse) if lit else colour * 0.12) * dark
		tiles[i].albedo_color = Color(0.92, 0.93, 0.95).lerp(Color(0.12, 0.12, 0.15), dark)
	sign_material.emission = PINK * (1.0 + 2.0 * pulse * dark)
	for i: int in spots.size():
		var a: float = beats * 0.45 + i * TAU / 4.0
		spots[i].light_color = Color.from_hsv(fposmod(i * 0.25 + beats * 0.02, 1.0), 0.9, 1.0)
		spots[i].light_energy = 7.0 * dark
		spots[i].look_at(Vector3(cos(a) * 5.0, 0.0, 1.0 + sin(a) * 3.0), Vector3.FORWARD)


func _look(from: Vector3, at: Vector3, fov: float = 52.0) -> void:
	camera.position = from
	camera.look_at(at, Vector3.UP)
	camera.fov = fov


func _camera(beats: float, frozen: bool, freeze_start: float, freeze_end: float, after: float) -> void:
	if _arg("cam", "") == "wide":
		_look(Vector3(0, 6.0, -13.0), Vector3(0, 1.5, 1.5), 60.0)
		return
	var a1: float = song["a1"]
	if song_time < a1:
		# He is alone on the floor, tapping his foot. We come in on him.
		var k: float = song_time / a1
		_look(Vector3(1.6 - 1.2 * k, 1.1, -5.2 + 1.6 * k), Vector3(0, 1.1, -1.0), 40.0)
		return
	if frozen:
		var into: float = out_time - freeze_start
		var span: float = freeze_end - freeze_start
		if into > span - 2.0 and into < span - 0.35:
			_look(Vector3(0.9, 1.6, -3.7), Vector3(0.0, 1.52, -1.0), 32.0)      # the glasses
		else:
			var a: float = -0.75 + 1.5 * (into / span)
			_look(Vector3(sin(a) * 8.0, 1.5 + 0.4 * sin(a * 2.0), 1.0 - cos(a) * 8.0), Vector3(0, 1.5, 1.6), 50.0)
		return
	if after > -0.2:
		_look(Vector3(-1.5, 2.3, -9.6), Vector3(1.2, 1.5, 1.6), 50.0)
		return
	var bars: float = beats / 2.0
	var section: int = int(floor(bars / 8.0))
	var within: float = fposmod(bars, 8.0)
	var k2: float = fposmod(within, 2.0) / 2.0
	if section == 0 or (section == 2 and within < 4.0):
		var w: float = within / 8.0
		if section == 2:
			_look(Vector3(0, 5.0 - 1.4 * (within / 4.0), -10.5 + 1.5 * (within / 4.0)), Vector3(0, 1.3, 1.5), 54.0)
		else:
			_look(Vector3(0, 2.3 - 0.4 * w, -11.0 + 2.6 * w), Vector3(0, 1.4, 1.2), 52.0)
	elif within < 2.0:
		_look(Vector3(-4.2 + 8.4 * k2, 0.45, 0.4), Vector3(-3.0 + 6.0 * k2, 1.5, 3.2), 58.0)       # the kick line, from the floor
	elif within < 4.0:
		var side: float = -1.0 if section == 1 else 1.0
		_look(Vector3(4.9 * side, 0.8, -1.0), Vector3(6.2 * side, 2.3, 1.8), 50.0)               # a gunner, from below
	elif within < 6.0:
		_look(Vector3(-2.6 + 5.2 * k2, 1.35, -3.4), Vector3(0, 1.2, 0.2), 48.0)                    # helpers and player
	else:
		if section == 3:
			_look(Vector3(-1.5, 2.3, -9.6), Vector3(1.2, 1.9, 1.6), 50.0)                            # wide, for what is coming
		else:
			_look(Vector3(1.3 - 0.6 * k2, 1.25, -3.6), Vector3(0, 1.15, -1.0), 38.0)                 # the player


func _captions(frozen: bool, freeze_start: float, after: float) -> void:
	caption.text = ""
	if out_time > 0.4 and song_time < float(song["a1"]) - 0.2:
		caption.text = "PINK DUDE HQ.  FRIDAY.  23:59."
	elif frozen:
		var into: float = out_time - freeze_start
		if into > 1.0 and into < 3.6:
			caption.text = "TIME ONLY MOVES WHEN YOU MOVE."
	elif after > 1.3 and after < 2.4:
		caption.text = "...anyway."
	title.modulate.a = clampf((after - 2.5) / 0.35, 0.0, 1.0)
