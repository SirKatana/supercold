extends Node
## Rewarded ads. There is one backend: a house ad, the trailer for The Last Ward, played
## from res://ads/the_last_ward.ogv. The game pauses while it runs.
##
## The reward is earned once `ad_reward_after` seconds have played. Closing sooner earns
## nothing. Watching to the end always earns it.
##
## To add a real ad network later, add a backend here that ends by calling `_finish(true)`
## or `_finish(false)`. Nothing outside this file needs to change.

signal started
signal finished(rewarded: bool)

const T: Tuning = preload("res://data/tuning.tres")
const VIDEO_PATH: String = "res://ads/the_last_ward.ogv"
const AD_TITLE: String = "THE LAST WARD"

## Tests and the smoke bot: skip the video and answer at once. 1 rewards, 0 refuses, -1 plays the ad.
var auto_result: int = -1
var showing: bool = false
var requests: int = 0

var _layer: CanvasLayer
var _video: VideoStreamPlayer
var _status: Label
var _claim: Button
var _skip: Button
var _bar: ColorRect
var _bar_back: ColorRect
var _elapsed: float = 0.0
var _length: float = 57.0
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_available() -> bool:
	return auto_result >= 0 or ResourceLoader.exists(VIDEO_PATH)


## Shows the ad. `finished` fires exactly once with whether the reward was earned.
func show_rewarded() -> void:
	if showing:
		return
	requests += 1
	if auto_result >= 0:
		started.emit()
		finished.emit(auto_result == 1)
		return
	if not ResourceLoader.exists(VIDEO_PATH):
		push_warning("ad video missing: %s" % VIDEO_PATH)
		finished.emit(false)
		return
	showing = true
	_elapsed = 0.0
	_build()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_video.play()
	started.emit()


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.03)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(back)

	# Keeps the recording's own shape. Without this the player stretches it to the window.
	var frame := AspectRatioContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_top = 46
	frame.offset_bottom = -76
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_layer.add_child(frame)
	_video = VideoStreamPlayer.new()
	_video.stream = load(VIDEO_PATH)
	_video.expand = true
	var picture: Texture2D = _video.get_video_texture()
	frame.ratio = 960.0 / 552.0 if picture == null or picture.get_height() == 0 else float(picture.get_width()) / picture.get_height()
	frame.add_child(_video)
	_video.volume_db = -80.0 if Settings.volume <= 0.001 else 0.0
	_video.finished.connect(func() -> void: _finish(true))
	_length = maxf(1.0, _video.get_stream_length()) if _video.get_stream_length() > 0.0 else 57.0

	var tag := Label.new()
	tag.text = "ADVERTISEMENT"
	tag.position = Vector2(18, 12)
	tag.add_theme_font_size_override(&"font_size", 16)
	tag.add_theme_color_override(&"font_color", Color(0.7, 0.72, 0.76))
	_layer.add_child(tag)

	var title := Label.new()
	title.text = AD_TITLE
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 6
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Color(0.96, 0.78, 0.42))
	_layer.add_child(title)

	_bar_back = ColorRect.new()
	_bar_back.color = Color(1, 1, 1, 0.12)
	_bar_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_back.offset_top = -70
	_bar_back.offset_bottom = -66
	_layer.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = Color(0.96, 0.78, 0.42)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.offset_top = -70
	_bar.offset_bottom = -66
	_layer.add_child(_bar)

	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 18
	_status.offset_top = -50
	_status.offset_bottom = -14
	_status.offset_right = 700
	_status.add_theme_font_size_override(&"font_size", 20)
	_status.add_theme_color_override(&"font_color", Color(0.92, 0.93, 0.95))
	_layer.add_child(_status)

	_claim = Button.new()
	_claim.text = "CLAIM HELPER"
	_claim.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_claim.offset_left = -220
	_claim.offset_right = -18
	_claim.offset_top = -54
	_claim.offset_bottom = -12
	_claim.disabled = true
	_claim.pressed.connect(func() -> void: _finish(true))
	_layer.add_child(_claim)

	_skip = Button.new()
	_skip.text = "CLOSE, NO HELPER"
	_skip.flat = true
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -440
	_skip.offset_right = -236
	_skip.offset_top = -54
	_skip.offset_bottom = -12
	_skip.pressed.connect(func() -> void: _finish(false))
	_layer.add_child(_skip)


func reward_earned() -> bool:
	return _elapsed >= T.ad_reward_after


func _process(delta: float) -> void:
	if not showing:
		return
	_elapsed += delta
	var width: float = _layer.get_viewport().get_visible_rect().size.x
	_bar.offset_right = width * clampf(_elapsed / _length, 0.0, 1.0)
	if reward_earned():
		_status.text = "HELPER EARNED. KEEP WATCHING OR CLAIM NOW."
		_claim.disabled = false
		_skip.visible = false
	else:
		_status.text = "HELPER IN 0:%02d" % int(ceilf(T.ad_reward_after - _elapsed))


func _finish(rewarded: bool) -> void:
	if not showing:
		return
	showing = false
	var earned: bool = rewarded and (reward_earned() or _elapsed >= _length - 0.5)
	if _video != null:
		_video.stop()
	if _layer != null:
		_layer.queue_free()
		_layer = null
	get_tree().paused = false
	Input.mouse_mode = _mouse_before
	finished.emit(earned)
