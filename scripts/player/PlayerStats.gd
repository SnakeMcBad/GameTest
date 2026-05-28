extends Resource
class_name PlayerStats

# Movement
@export var move_speed: float = 220.0
@export var acceleration: float = 1800.0
@export var friction: float = 2000.0
@export var air_friction: float = 600.0

# Jumping
@export var jump_velocity: float = -520.0
@export var jump_cut_multiplier: float = 0.45   # velocity multiplied when jump released early
@export var double_jump_velocity: float = -480.0
@export var gravity_scale: float = 1.0
@export var fall_gravity_multiplier: float = 1.6  # faster fall after apex
@export var max_fall_speed: float = 900.0

# Coyote time & jump buffer
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.14

# Wall mechanics
@export var wall_slide_speed: float = 80.0
@export var wall_jump_velocity: Vector2 = Vector2(260.0, -480.0)
@export var wall_jump_lock_time: float = 0.18  # prevents immediately overriding wall jump direction

# Dash
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.55
@export var dash_invincible: bool = true

# Combat
@export var max_health: int = 5
@export var attack_cooldown: float = 0.35
@export var attack_duration: float = 0.2
@export var knockback_force_received: Vector2 = Vector2(280.0, -180.0)
@export var knockback_force_dealt: Vector2 = Vector2(160.0, -80.0)  # recoil on player when attacking
@export var knockback_duration: float = 0.22
@export var invincibility_duration: float = 1.2
@export var down_attack_bounce: float = -400.0  # bounce when hitting down attack
