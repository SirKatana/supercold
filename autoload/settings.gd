extends Node
## Player preferences, persisted to user://settings.cfg.

signal changed

const PATH: String = "user://settings.cfg"

var mouse_sensitivity: float = 0.12
var fov: float = 85.0
var volume: float = 0.8
## Pink dudes and security wear sunglasses. Some people would rather they did not.
var sunglasses: bool = true
## The minimap in the corner: off, or on with a dot per enemy. Each kind of dude has its own
## colour, so a crowd of pink with one violet in it reads at a glance.
var minimap: bool = false
var _read_only: bool = false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	fov = float(cfg.get_value("video", "fov", fov))
	volume = float(cfg.get_value("audio", "volume", volume))
	sunglasses = bool(cfg.get_value("video", "sunglasses", sunglasses))
	minimap = bool(cfg.get_value("video", "minimap", minimap))
	_apply_volume()


## Tests and the smoke bot call this: factory values, and nothing is ever written back to the
## player's file. Otherwise whatever the player chose in the pause menu decides whether tests pass.
func use_defaults_for_tests() -> void:
	mouse_sensitivity = 0.12
	fov = 85.0
	volume = 0.8
	sunglasses = true
	minimap = false
	_read_only = true


func save_settings() -> void:
	if _read_only:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "sunglasses", sunglasses)
	cfg.set_value("video", "minimap", minimap)
	cfg.save(PATH)


func apply() -> void:
	_apply_volume()
	changed.emit()
	save_settings()


func _apply_volume() -> void:
	var bus: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
