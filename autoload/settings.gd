extends Node
## Player preferences, persisted to user://settings.cfg.

signal changed

const PATH: String = "user://settings.cfg"

var mouse_sensitivity: float = 0.12
var fov: float = 85.0
var volume: float = 0.8
## Pink dudes and security wear sunglasses. Some people would rather they did not.
var sunglasses: bool = true


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
	_apply_volume()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "sunglasses", sunglasses)
	cfg.save(PATH)


func apply() -> void:
	_apply_volume()
	changed.emit()
	save_settings()


func _apply_volume() -> void:
	var bus: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
