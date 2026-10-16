class_name CampConfig
extends Resource
## Shared gameplay values. Offline authority uses the same rules intended for M2.

@export var walk_speed: float = 70.0
@export var sprint_speed: float = 110.0
@export var stamina_max: float = 4.0
@export var stamina_recovery: float = 0.8
@export var stamina_restart: float = 1.0
@export var interact_radius: float = 25.0
@export var start_hold_seconds: float = 2.0
@export var extraction_seconds: float = 8.0
@export var boarding_radius: float = 32.0
@export var revive_seconds: float = 3.0
@export var revive_grace_seconds: float = 2.0
@export var bleedout_seconds: float = 16.0
@export var attack_cooldown: float = 2.0
@export var attack_radius: float = 13.0
@export var killer_patrol_speed: float = 38.0
@export var killer_chase_speed: float = 77.0
@export var sight_radius: float = 110.0
@export var hearing_radius: float = 150.0
@export var memory_seconds: float = 6.0
@export var search_seconds: float = 4.0
@export var sprint_noise_interval: float = 0.7
@export var night_ambient: Color = Color(0.035, 0.045, 0.065, 1.0)
@export var flashlight_range: float = 220.0

@export var flashlight_capacity: float = 90.0
