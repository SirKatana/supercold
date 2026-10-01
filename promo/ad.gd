extends Node3D
## The house ads. Five of them, thirty seconds each, rendered offscreen by tools/make_ads.sh
## and played back by AdService when somebody hits the capsule button.
##
## They are adverts for this game, made out of this game: the same Humanoid, the same guns, the
## same pink. Every one of them ends in a cha-cha, because the helper has to earn his four
## minutes somehow.
##
## Which one is rendered comes from `--ad=1..5`. `--at=12.5 --shot=/tmp/x.png` saves one frame
## of it for checking. Not part of the game: promo/ is excluded from both export presets.

const Dancer: GDScript = preload("res://promo/dancer.gd")
const PINK := Color(1.0, 0.176, 0.584)
const LENGTH: float = 30.0
const BEAT: float = 0.5          # 120 BPM, matching tools/make_cha_cha.py
const BAR: float = 2.0

## Every ad: who is in it, what it is called, and the words that come up over it.
## A caption is [when, how long, text].
const ADS: Array[Dictionary] = [
	{
		"name": "HELPER FOR HIRE",
		"tag": "FOUR MINUTES. NO CHARGE.",
		"captions": [
			[0.6, 3.2, "OUTNUMBERED?"],
			[4.2, 3.0, "SURROUNDED?"],
			[7.6, 3.4, "HIT THE BUTTON."],
			[11.4, 3.2, "HE BRINGS HIS OWN RIFLE."],
			[15.2, 3.4, "FOUR WHOLE MINUTES."],
			[19.2, 3.6, "AND HE DANCES."],
			[23.4, 4.6, "SUPERCOLD HELPER\nFREE WITH ONE ADVERT"],
		],
	},
	{
		"name": "TIME MANAGEMENT",
		"tag": "STAND STILL. STAY ALIVE.",
		"captions": [
			[0.6, 3.4, "THEY SHOT AT YOU."],
			[4.4, 3.4, "SO STOP MOVING."],
			[8.2, 3.6, "TIME STOPS WITH YOU."],
			[12.4, 3.4, "WALK AROUND IT."],
			[16.2, 3.4, "THEN KEEP DANCING."],
			[20.0, 3.6, "TIME ONLY MOVES\nWHEN YOU DO."],
			[24.2, 4.0, "SUPERCOLD"],
		],
	},
	{
		"name": "THE GENTLEMAN",
		"tag": "1800s TECHNOLOGY. FULL RECOIL.",
		"captions": [
			[0.6, 3.4, "MEET THE GENTLEMAN."],
			[4.4, 3.2, "HAT. MOUSTACHE. BLUNDERBUSS."],
			[8.0, 3.2, "HE FIRES ONCE."],
			[11.6, 3.4, "AND LEAVES AT SPEED."],
			[15.4, 3.6, "THE RECOIL IS YOUR WINDOW."],
			[19.6, 3.8, "SO IS THE CHA-CHA."],
			[24.0, 4.2, "SUPERCOLD\nLEVEL 5 AND EVERY FLOOR AFTER"],
		],
	},
	{
		"name": "WET FLOOR",
		"tag": "THE CLEANER WORKS HERE. YOU DON'T.",
		"captions": [
			[0.6, 3.2, "TIP OUT THE BUCKET."],
			[4.2, 3.4, "STAND BACK."],
			[8.0, 3.6, "THEY RUN EVERYWHERE."],
			[12.0, 3.4, "THEY RUN ONCE."],
			[15.8, 3.6, "THE CLEANER IS FURIOUS."],
			[19.8, 3.8, "THE CLEANER IS ALSO DANCING."],
			[24.2, 4.0, "SUPERCOLD\nMIND THE FLOOR"],
		],
	},
	{
		"name": "EVERY GUN",
		"tag": "TWELVE GUNS. ALL ON THE FLOOR.",
		"captions": [
			[0.6, 3.2, "PISTOL."],
			[3.6, 2.8, "SHOTGUN."],
			[6.4, 2.8, "AK. SMG. REVOLVER."],
			[9.6, 3.2, "SNIPER RIFLE. CROSSBOW."],
			[13.2, 3.4, "A SPEAR, FOR SOME REASON."],
			[17.0, 3.6, "ALL OF THEM FREE."],
			[21.0, 3.6, "ALL OF THEM ON THE FLOOR."],
			[25.0, 3.8, "SUPERCOLD\nCOME AND PICK ONE UP"],
		],
	},
]

var which: int = 0
var ad: Dictionary
var t: float = 0.0
var _frames: int = 0
var _shot_path: String = ""

var caption: Label
var tag: Label
var end_card: ColorRect
var camera: Camera3D
var spots: Array[SpotLight3D] = []
var tiles: Array[StandardMaterial3D] = []

var star: Node3D                       # whoever the ad is about
var agent: Node3D                      # the man from the title screen, in every one of them
## Anyone else with a speaking part. A Humanoid that is never posed collapses into a blob at
## the world origin, so everything built as a dancer has to be driven every frame.
var extras: Array[Node3D] = []
var crowd: Array[Node3D] = []          # the pink dudes
var down_at: PackedFloat32Array = PackedFloat32Array()   # when each of them goes over, or -1
var props: Array[Node3D] = []
var tracers: Array[MeshInstance3D] = []


func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return fallback


func _ready() -> void:
	which = clampi(int(_arg("ad", "1")) - 1, 0, ADS.size() - 1)
	ad = ADS[which]
	_shot_path = _arg("shot", "")
	HelperVoice.tts_enabled = false
	TimeManager.override_scale = 1.0
	_build_stage()
	_build_cast()
	_build_overlay()
	t = float(_arg("at", "0"))
	_update()


func _process(delta: float) -> void:
	_frames += 1
	if _shot_path != "":
		if _frames == 4:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()
		_update()
		return
	t += delta
	_update()
	if t >= LENGTH:
		get_tree().quit()


# ------------------------------------------------------------------ the room

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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.94, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.92, 1.0)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, 155, 0)
	sun.light_energy = 0.7
	add_child(sun)

	# A floor of tiles that light up on the beat, and the white room round it.
	for ix: int in 10:
		for iz: int in 7:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.92, 0.93, 0.95)
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission = Color.BLACK
			tiles.append(m)
			_box(Vector3(1.16, 0.1, 1.16), Vector3((ix - 4.5) * 1.2, -0.05, (iz - 3.6) * 1.2), m)
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.70, 0.71, 0.75)
	_box(Vector3(60, 0.1, 60), Vector3(0, -0.12, 0), ground)
	_box(Vector3(18, 7.5, 0.3), Vector3(0, 3.7, 7.0), Mats.wall())

	for i: int in 2:
		var word := Label3D.new()
		word.text = ["SUPER", "COLD"][i]
		word.font_size = 220
		word.pixel_size = 0.0030
		word.modulate = Color(0.06, 0.06, 0.08) if i == 0 else PINK
		word.position = Vector3(0, 4.35 - i * 0.72, 6.8)
		word.rotation.y = PI
		word.shaded = false
		add_child(word)

	for i: int in 4:
		var spot := SpotLight3D.new()
		spot.spot_angle = 26.0
		spot.spot_range = 17.0
		spot.light_energy = 3.0
		spot.light_color = PINK if i % 2 == 0 else Color(0.5, 0.75, 1.0)
		spot.position = Vector3(-4.5 + i * 3.0, 5.6, 1.2)
		spot.rotation_degrees = Vector3(-72, 0, 0)
		add_child(spot)
		spots.append(spot)

	camera = Camera3D.new()
	camera.fov = 52.0
	camera.look_at_from_position(Vector3(0.0, 2.05, -7.4), Vector3(0, 1.25, 0.6), Vector3.UP)
	add_child(camera)
	camera.current = true


func _dancer(material: Material, at: Vector3, scale_factor: float = 1.0, mirrored: bool = false) -> Node3D:
	var d: Node3D = Dancer.new()
	add_child(d)
	d.position = at
	d.call(&"setup", material, scale_factor, true)
	d.set(&"mirrored", mirrored)
	return d


## The cast changes with the ad, but the shape is always the same: the agent, whoever the ad
## is about, and some pink dudes.
func _build_cast() -> void:
	down_at = PackedFloat32Array()
	_build_agent()
	match which:
		0:      # helper for hire
			star = _dancer(Mats.helper_red(), Vector3(0, 0, -0.35), 1.0)
			star.call(&"hold", Rifle.create())
			for i: int in 4:
				crowd.append(_dancer(Mats.pink(), Vector3((i - 1.5) * 1.25, 0, 1.15), 1.0, i % 2 == 1))
				down_at.append(11.0 + i * 1.1)
		1:      # time management -- the agent is the one being advertised at here
			star = agent
			agent = null
			for i: int in 3:
				crowd.append(_dancer(Mats.pink(), Vector3((i - 1.0) * 1.65, 0, 1.35), 1.0, i % 2 == 1))
				down_at.append(-1.0)
			for i: int in 3:
				tracers.append(_tracer(Vector3((i - 1.0) * 1.9, 1.25, 1.0)))
		2:      # the gentleman
			star = _dancer(Mats.gentleman_coat(), Vector3(0, 0, 0.2), 1.0)
			star.call(&"wear", &"gentleman")
			star.call(&"hold", Blunderbuss.create())
			for i: int in 4:
				crowd.append(_dancer(Mats.pink(), Vector3((i - 1.5) * 1.25, 0, 1.30), 1.0, i % 2 == 1))
				down_at.append(-1.0)
		3:      # wet floor
			star = _dancer(Mats.overalls(), Vector3(-1.5, 0, 0.6), 1.0)
			star.call(&"wear", &"cleaner")
			props.append(_broom())
			for i: int in 4:
				crowd.append(_dancer(Mats.pink(), Vector3((i - 1.5) * 1.25, 0, 1.25), 1.0, i % 2 == 1))
				down_at.append(8.0 + i * 1.3)
			_puddle()
		_:      # every gun, with the man who confiscates them watching
			star = _dancer(Mats.helper_red(), Vector3(0, 0, -0.3), 1.0)
			var guard: Node3D = _dancer(Mats.security_suit(), Vector3(2.35, 0, 0.1), 1.04)
			guard.call(&"wear", &"guard")
			extras.append(guard)
			for i: int in 4:
				crowd.append(_dancer(Mats.pink(), Vector3((i - 1.5) * 1.3, 0, 1.30), 1.0, i % 2 == 1))
				down_at.append(-1.0)
			_gun_rack()


## A pink round hanging in the air, for the ad about standing still.
## The agent: black suit, shades, standing where he can be seen. In the ad about standing
## still he is the star and this one is handed over instead of a second figure.
func _build_agent() -> void:
	# Black from head to foot, like the player's own body in the game. The shades are the
	# only thing that says agent; a pink head would just make him another dude.
	agent = _dancer(Mats.black(), Vector3(-2.05, 0, -0.1), 1.02)
	var pistol: Gun = Pistol.create()
	agent.call(&"hold", pistol)


func _tracer(at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.55)
	var m := StandardMaterial3D.new()
	m.albedo_color = PINK
	m.emission_enabled = true
	m.emission = PINK
	m.emission_energy_multiplier = 2.2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi


func _broom() -> Node3D:
	var broom := Node3D.new()
	var handle := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.025
	rod.height = 1.5
	handle.mesh = rod
	handle.material_override = Mats.wood()
	handle.rotation.x = PI * 0.5
	handle.position.z = -0.55
	broom.add_child(handle)
	var head := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(0.44, 0.09, 0.14)
	head.mesh = block
	head.material_override = Mats.bristle()
	head.position.z = -1.25
	broom.add_child(head)
	broom.name = "Broom"
	add_child(broom)
	return broom


func _puddle() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.4
	mesh.bottom_radius = 2.4
	mesh.height = 0.02
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.water()
	mi.position = Vector3(0.4, 0.015, 2.0)
	add_child(mi)


## The guns, lying in a row where the ad can sweep past them.
func _gun_rack() -> void:
	var kinds: Array[StringName] = [&"pistol", &"shotgun", &"rifle", &"smg", &"revolver", &"sniper", &"crossbow"]
	for i: int in kinds.size():
		var gun: Gun = PinkDude.create_gun(kinds[i])
		add_child(gun)
		gun.state = Pickup.State.HELD
		gun.position = Vector3((i - 3.0) * 1.1, 0.95, 2.9)
		gun.rotation = Vector3(0, PI * 0.5, 0)
		props.append(gun)


# ------------------------------------------------------------------ overlay

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var badge := Label.new()
	badge.text = "ADVERTISEMENT"
	badge.position = Vector2(22, 16)
	badge.add_theme_font_size_override(&"font_size", 18)
	badge.add_theme_color_override(&"font_color", Color(0.25, 0.26, 0.3))
	layer.add_child(badge)

	tag = Label.new()
	tag.text = str(ad["name"])
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tag.offset_top = 14
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override(&"font_size", 28)
	tag.add_theme_color_override(&"font_color", PINK)
	layer.add_child(tag)

	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption.position.y -= 120
	caption.add_theme_font_size_override(&"font_size", 44)
	caption.add_theme_color_override(&"font_color", Color.WHITE)
	caption.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.07))
	caption.add_theme_constant_override(&"outline_size", 16)
	layer.add_child(caption)

	end_card = ColorRect.new()
	end_card.color = Color(0.94, 0.95, 0.97)
	end_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_card.modulate.a = 0.0
	layer.add_child(end_card)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_card.add_child(box)
	for row: Array in [["SUPER", 150, Color(0.06, 0.06, 0.08)], ["COLD", 150, PINK],
			[str(ad["tag"]), 32, Color(0.06, 0.06, 0.08)],
			["no pink dudes were harmed in the making of this advert", 20, Color(0.35, 0.36, 0.4)]]:
		var l := Label.new()
		l.text = row[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override(&"font_size", row[1])
		l.add_theme_color_override(&"font_color", row[2])
		box.add_child(l)


# ------------------------------------------------------------------ the show

func _update() -> void:
	var beats: float = t / BEAT
	_lights(beats)
	_captions()
	_cast(beats)
	_camera_move()
	end_card.modulate.a = clampf((t - (LENGTH - 4.2)) / 0.7, 0.0, 1.0)


func _lights(beats: float) -> void:
	var pulse: float = pow(absf(cos(PI * beats)), 3.0)
	for i: int in tiles.size():
		var lit: float = pow(absf(sin(PI * (beats * 0.5 + i * 0.11))), 6.0)
		tiles[i].emission = (PINK if i % 2 == 0 else Color(0.45, 0.7, 1.0)) * lit * 0.9
	for i: int in spots.size():
		spots[i].light_energy = 2.0 + 2.4 * pow(absf(cos(PI * (beats + i * 0.25))), 2.0)
		spots[i].rotation_degrees.y = sin(beats * 0.6 + i) * 16.0
	if camera != null:
		camera.fov = 52.0 - 1.2 * pulse


func _captions() -> void:
	caption.text = ""
	if t >= LENGTH - 4.4:
		return      # the end card is coming up; two lots of words on top of each other is a mess
	for row: Array in ad["captions"]:
		if t >= float(row[0]) and t < float(row[0]) + float(row[1]):
			caption.text = str(row[2])
			var age: float = t - float(row[0])
			caption.modulate.a = clampf(age / 0.18, 0.0, 1.0) * clampf((float(row[1]) - age) / 0.3, 0.0, 1.0)
			return


## The camera drifts in on the star and pulls out for the dance.
func _camera_move() -> void:
	var dance_from: float = LENGTH - 11.0
	var close: float = clampf(t / 6.0, 0.0, 1.0)
	var out: float = clampf((t - dance_from) / 2.5, 0.0, 1.0)
	var distance: float = lerpf(4.2, 3.1, close)
	distance = lerpf(distance, 3.9, out)
	var height: float = lerpf(1.55, 1.35, close)
	height = lerpf(height, 1.45, out)
	var swing: float = sin(t * 0.22) * 0.8
	camera.look_at_from_position(Vector3(swing, height, -distance), Vector3(0, 1.00, 1.0), Vector3.UP)


## Everybody's moves. The last third of every ad is the cha-cha, whatever the ad was about.
func _cast(beats: float) -> void:
	var dance_from: float = LENGTH - 11.0
	var dancing: bool = t >= dance_from
	var blend: float = clampf((t - dance_from) / 0.8, 0.0, 1.0)

	for i: int in crowd.size():
		var dude: Node3D = crowd[i]
		var floored: bool = down_at[i] > 0.0 and t >= down_at[i]
		if floored and not dancing:
			_lay_out(dude, t - down_at[i])
			continue
		dude.rotation = Vector3(0, 0, 0)      # straight down the lens
		dude.position.y = 0.0
		if dancing:
			dude.call(&"dance", &"cha_cha", beats + i * 0.0, blend)
		else:
			dude.call(&"dance", _crowd_move(i), beats, 1.0)

	for extra: Node3D in extras:
		extra.rotation = Vector3(0, 0, 0)
		if dancing:
			extra.call(&"dance", &"cha_cha", beats + 3.0, blend)
		else:
			extra.call(&"dance", &"tap", beats, 1.0)
	if agent != null and is_instance_valid(agent):
		agent.rotation = Vector3(0, 0, 0)
		if dancing:
			agent.call(&"dance", &"cha_cha", beats + 1.0, blend)
		else:
			agent.call(&"dance", &"tap", beats, 1.0)
	if star == null:
		return
	star.rotation = Vector3(0, 0, 0)
	star.position.y = 0.0
	if dancing:
		star.call(&"dance", &"cha_cha", beats + 2.0, blend)
	else:
		_star_move(beats)
	_place_props(beats)


## What the pink dudes do before the music takes over.
func _crowd_move(i: int) -> StringName:
	match which:
		0: return &"wave"
		1: return &"gun_up"
		2: return &"tap"
		3: return &"tap"
		_: return &"wave"


## The gag, ad by ad. Each one is a function of `t`, so any frame stands on its own.
func _star_move(beats: float) -> void:
	match which:
		0:      # he turns up at 8 s and starts shooting
			if t < 8.0:
				star.visible = false
				return
			star.visible = true
			star.position.x = lerpf(-5.0, 0.0, clampf((t - 8.0) / 1.6, 0.0, 1.0))
			star.call(&"dance", &"gun_up", beats, 1.0, pow(absf(sin(PI * t * 2.0)), 6.0))
		1:      # he stands dead still; the rounds crawl past him
			star.call(&"dance", &"still", beats, 1.0)
			for i: int in tracers.size():
				var crawl: float = 2.4 - fposmod(t * 0.42 + i * 0.9, 5.4)
				tracers[i].position.z = crawl
				tracers[i].visible = t < LENGTH - 11.0
		2:      # he fires once and is thrown out of frame by his own gun
			var fire_at: float = 9.4
			if t < fire_at:
				star.call(&"dance", &"gun_up", beats, 1.0)
				star.position.z = 0.2
				return
			var since: float = t - fire_at
			star.call(&"dance", &"gun_up", beats, 1.0, exp(-since * 2.2))
			# Straight backwards and down: the blunderbuss wins.
			star.position.z = 0.2 + minf(since * 3.4, 6.0)
			star.rotation = Vector3(-minf(since * 1.9, PI * 0.5), 0, 0)
			star.position.y = maxf(0.0, 0.5 * sin(minf(since, 1.0) * PI) - 0.05 * since)
		3:      # he mops, then stands back and watches them go over
			star.call(&"dance", &"tap" if t > 7.0 else &"wave", beats, 1.0)
			star.position.x = lerpf(-1.5, -1.1, clampf((t - 6.0) / 2.0, 0.0, 1.0))
		_:      # he picks up gun after gun
			star.call(&"dance", &"gun_up", beats, 1.0, pow(absf(sin(PI * t)), 8.0))


## Props that have to follow somebody: the hat, the broom, the row of guns.
func _place_props(beats: float) -> void:
	for prop: Node3D in props:
		if prop.name == "Broom" and star != null:
			# Held in the cleaner's hands, angled down at the floor he is so proud of.
			var hands: PackedVector3Array = star.get(&"joints")
			if hands.size() > Humanoid.index_of(&"hand_r"):
				prop.global_position = hands[Humanoid.index_of(&"hand_r")]
				# Head down on the floor in front of him, handle up to his hands.
				prop.rotation = Vector3(1.05, star.rotation.y + PI - 0.3, 0.0)
		elif prop is Gun:
			# The guns turn on the spot like a shopping channel turntable.
			prop.rotation.y = PI * 0.5 + beats * 0.35
			prop.position.y = 0.95 + 0.06 * sin(beats * 1.4 + prop.position.x)


## A dude going over: he keels backwards and stays there.
func _lay_out(dude: Node3D, since: float) -> void:
	dude.call(&"dance", &"still", 0.0, 1.0)
	var fall: float = clampf(since / 0.55, 0.0, 1.0)
	fall = fall * fall * (3.0 - 2.0 * fall)
	dude.rotation = Vector3(-PI * 0.5 * fall, 0, 0)
	dude.position.y = -0.02 * fall
