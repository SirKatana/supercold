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
@export var death_restart_delay: float = 2.4
@export var ragdoll_speed: float = 0.75
@export var punch_range: float = 1.6
@export var punch_cooldown: float = 0.4
@export var pickup_range: float = 2.5
@export var pickup_cone_deg: float = 12.0

@export_group("Weapons")
@export var pistol_ammo: int = 6
@export var pistol_cooldown: float = 0.35
@export var enemy_drop_ammo: int = 4
## AK-47: hold the trigger. The cooldown is world time, so standing still it fires slowly too.
@export var rifle_ammo: int = 30
@export var rifle_cooldown: float = 0.10
@export var rifle_spread_deg: float = 1.1
@export var rifle_enemy_burst: int = 3
@export var rifle_drop_ammo: int = 12
## Pump shotgun: one pull throws a cone of pellets, then it has to be racked.
@export var shotgun_ammo: int = 5
@export var shotgun_pellets: int = 8
@export var shotgun_spread_deg: float = 5.5
@export var shotgun_cooldown: float = 0.85
@export var shotgun_enemy_pellets: int = 5
@export var shotgun_enemy_range: float = 10.0
@export var shotgun_drop_ammo: int = 3
@export var bullet_speed: float = 12.0
@export var bullet_life: float = 8.0
@export var throw_speed: float = 16.0
@export var throw_gravity: float = 9.8
@export var throw_stun: float = 1.2
@export var throw_damage: int = 1

@export_group("Wall breaker")
## The ram survives this many bashes, then cracks in half. A door costs one bash,
## a wall section costs `ram_wall_hits` (the first cracks it, the last opens it).
@export var ram_hits: int = 5
@export var ram_wall_hits: int = 2
@export var ram_cooldown: float = 0.55
@export var ram_range: float = 2.3
@export var ram_throw_damage: int = 3

@export_group("Shield and barrels")
## A bullet that strikes a ballistic shield ricochets this often. Otherwise it just stops.
@export var shield_deflect_chance: float = 0.3333
@export var shield_dude_speed: float = 2.1
@export var shield_dude_cadence: float = 1.9
@export var shield_pickup_range: float = 2.8
## Gas barrel: dudes inside the radius die, the player dies inside the inner radius.
## Walls block the blast.
@export var barrel_radius: float = 5.5
@export var barrel_player_radius: float = 3.6
@export var barrel_chain_delay: float = 0.12
@export var barrel_throw_speed: float = 11.0

@export_group("Cold, wet and smelly")
## Freeze bomb: every dude in the radius is frozen solid. Any hit shatters a frozen dude.
@export var freeze_radius: float = 5.5
@export var freeze_seconds: float = 7.0
## Water and ice: a dude moving faster than this over a wet cell goes down and loses his gun.
@export var slip_speed: float = 1.6
@export var slip_seconds: float = 2.4
@export var slip_again_after: float = 4.0
## Water bucket: one pour. The spill is this wide and dries up after this many real seconds.
@export var spill_radius: float = 2.4
@export var spill_seconds: float = 90.0
@export var pour_reach: float = 3.2
## Deep water: how far down the pool goes, and how the player moves in it.
@export var pool_depth: float = 2.2
@export var swim_speed: float = 3.0
@export var swim_up_speed: float = 3.2
@export var swim_sink_speed: float = 1.4
@export var swim_hop_out: float = 5.4
## Fart cloud: drifting it is small, shot it fills a room. A dude who breathes it this long dies.
@export var fart_small_radius: float = 1.5
@export var fart_big_radius: float = 6.5
@export var fart_big_seconds: float = 8.0
@export var fart_kill_time: float = 2.2
@export var fart_drift_speed: float = 0.9
## Knife: one stab kills an ordinary dude.
@export var knife_range: float = 1.9
@export var knife_cooldown: float = 0.32
## Melting under the super gun takes this long, world seconds.
@export var melt_seconds: float = 1.3

@export_group("More guns")
@export var smg_ammo: int = 24
@export var smg_cooldown: float = 0.065
@export var smg_spread_deg: float = 3.2
@export var revolver_ammo: int = 5
@export var revolver_cooldown: float = 0.6
@export var revolver_pierce: int = 2
@export var sniper_ammo: int = 4
@export var sniper_cooldown: float = 1.1
@export var sniper_speed_scale: float = 3.0
@export var sniper_pierce: int = 4
@export var sniper_enemy_aim_time: float = 1.5
## Holding right click with the sniper rifle looks through the scope.
@export var scope_fov: float = 14.0
@export var scope_zoom_speed: float = 9.0
## Super gun: a laser. Instant, goes through every dude in line, melts them. Recharges each level.
@export var super_charges: int = 8
@export var super_cooldown: float = 0.45
@export var super_range: float = 70.0

@export_group("More dudes")
@export var runner_speed: float = 6.4
@export var runner_windup: float = 0.28
@export var zombie_wake_distance: float = 9.0
@export var zombie_rise_seconds: float = 1.5
@export var zombie_shamble: float = 1.9
@export var zombie_lunge: float = 4.6
@export var zombie_lunge_distance: float = 3.2
@export var zombie_bite_range: float = 1.25
@export var brute_scale: float = 1.75
@export var brute_hp: int = 12
@export var brute_speed: float = 2.4
@export var brute_slam_range: float = 2.6
@export var warden_scale: float = 1.45
@export var warden_glass_hits: int = 3

@export_group("Security")
## The guard waits this far outside the arrival lift, and shoots once an armed player is this far past him.
@export var guard_distance: float = 5.0
@export var guard_line: float = 1.2
## He catches a thrown weapon that comes this close to his chest, and picks one up off the floor
## once he has walked to within `guard_floor_reach` of it.
@export var guard_catch_range: float = 1.7
@export var guard_floor_reach: float = 1.3
## Walking to a dropped weapon (real time) and running an armed player down (world time, and
## faster than the player walks, so running away does not work).
@export var guard_fetch_speed: float = 3.4
@export var guard_chase_speed: float = 5.8
## Under fire he closes to this distance and keeps shooting from there.
@export var guard_chase_keep: float = 4.5
@export var guard_cadence: float = 0.32
@export var guard_bullet_speed: float = 2.2

@export_group("Helper")
## Die this many times on one floor and the helper capsule is waiting outside the lift.
@export var helper_deaths_needed: int = 3
## Real seconds of help. It also ends the moment the floor is clear.
@export var helper_seconds: float = 240.0
@export var helper_speed: float = 4.4
@export var helper_follow_distance: float = 3.5
@export var helper_aim_time: float = 0.35
@export var helper_cadence: float = 0.55
@export var helper_sight: float = 34.0
## The helper is earned this far into the 57 second ad. Closing it sooner earns nothing.
@export var ad_reward_after: float = 20.0

@export_group("Pink dude")
@export var dude_speed: float = 3.2
@export var dude_run_speed: float = 4.3
@export var dude_hp: int = 3
## Each dude picks its own spot on a ring around the player, so they surround instead of queueing.
@export var dude_ring_min: float = 6.0
@export var dude_ring_max: float = 11.0
@export var dude_separation_radius: float = 2.2
@export var dude_separation_push: float = 2.0
## Between shots a dude runs for cover and stays hidden this long (world seconds).
@export var dude_cover_search_radius: float = 6.0
@export var dude_hide_min: float = 0.5
@export var dude_hide_max: float = 1.3
@export var dude_reposition_max: float = 3.0
## A dead dude falls as a ragdoll on world time, then bursts into shards after this long.
@export var dude_ragdoll_shatter: float = 2.0
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
@export var elevator_ride_seconds: float = 4.5
