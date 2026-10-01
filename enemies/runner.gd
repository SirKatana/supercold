class_name Runner
extends PinkDude
## Fast pink dude. No gun, no cover, no patience: he sprints straight at you and swings.
## Twice your walking speed, so you cannot outrun him. Water is his enemy.


func _ready() -> void:
	armed_at_spawn = false
	body_scale = 0.94
	body_material = Mats.hot_pink()
	super()
	hp = 2
	seeks_weapons = false


func voice_name_id() -> StringName:
	return &"name_runner"


func seeks_cover() -> bool:
	return false


func move_speed() -> float:
	return T.runner_speed


func punch_windup() -> float:
	return T.runner_windup


func display_name() -> String:
	return "A RUNNER"
