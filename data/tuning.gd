class_name Tuning
extends Resource
## Every gameplay number lives here. Entity scripts read from the shared
## instance at res://data/tuning.tres and never hard-code values.

@export_group("Time")
@export var min_scale: float = 0.06
@export var look_weight: float = 0.30
@export var look_full_deg_per_sec: float = 360.0
## Acting nudges time forward instead of snapping it to full speed, so you watch
## your own bullet leave the barrel. Each burst has a length (real seconds) and a strength (scale).
@export var burst_action: float = 0.12
@export var burst_pickup: float = 0.08
@export var burst_strength_shot: float = 0.22
@export var burst_strength_throw: float = 0.30
@export var burst_strength_punch: float = 0.55
@export var burst_strength_pickup: float = 0.15
@export var burst_strength_break: float = 0.40
@export var scale_rise_rate: float = 12.0
@export var scale_fall_rate: float = 5.0
@export var pitch_floor: float = 0.35

@export_group("Player")
@export var walk_speed: float = 5.0
@export var accel: float = 40.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 12.0
@export var eye_height: float = 1.6
@export var death_restart_delay: float = 0.6
@export var punch_range: float = 1.6
@export var punch_cooldown: float = 0.4
@export var pickup_range: float = 2.5
@export var pickup_cone_deg: float = 12.0

@export_group("Weapons")
@export var pistol_ammo: int = 6
@export var pistol_cooldown: float = 0.35
@export var enemy_drop_ammo: int = 4
@export var bullet_speed: float = 12.0
@export var bullet_life: float = 8.0
@export var throw_speed: float = 16.0
@export var throw_gravity: float = 9.8
@export var throw_stun: float = 1.2
@export var throw_damage: int = 1

@export_group("Pink dude")
@export var dude_speed: float = 3.2
@export var dude_hp: int = 3
@export var dude_reaction: float = 0.3
@export var dude_aim_time: float = 0.7
@export var dude_cadence: float = 1.4
@export var dude_spread_deg: float = 1.5
@export var dude_sight: float = 40.0
@export var dude_engage_dist: float = 16.0
@export var dude_hearing: float = 14.0
@export var dude_seek_weapon_dist: float = 12.0
@export var dude_punch_range: float = 1.5
@export var dude_punch_windup: float = 0.5

@export_group("Director")
@export var director_scale: float = 1.3
@export var director_hp: int = 3
@export var director_cadence: float = 0.7
@export var director_flinch: float = 1.0
@export var director_wave_size: int = 4

@export_group("World")
@export var cell_size: float = 2.0
@export var wall_height: float = 3.0
@export var door_hp: int = 2
@export var door_damage_punch: int = 1
@export var door_damage_throw: int = 2
@export var door_damage_bullet: int = 1
@export var glass_hp: int = 1
@export var shard_life: float = 3.0
@export var door_shard_stun_radius: float = 2.5
