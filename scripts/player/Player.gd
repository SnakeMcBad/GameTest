extends CharacterBody2D
class_name Player

# ── References ────────────────────────────────────────────────────────────────
@export var stats: PlayerStats

@onready var sprite: AnimatedSprite2D      = $AnimatedSprite2D
@onready var hitbox_right: Hitbox          = $AttackPivot/HitboxRight
@onready var hitbox_left: Hitbox           = $AttackPivot/HitboxLeft
@onready var hitbox_up: Hitbox             = $AttackPivot/HitboxUp
@onready var hitbox_down: Hitbox           = $AttackPivot/HitboxDown
@onready var hurtbox: Hurtbox              = $Hurtbox
@onready var wall_ray_left: RayCast2D      = $WallRayLeft
@onready var wall_ray_right: RayCast2D     = $WallRayRight
@onready var coyote_timer: Timer           = $CoyoteTimer
@onready var dash_trail: GPUParticles2D    = $DashTrail
@onready var debug_shape: Polygon2D        = $DebugShape

# ── State machine ─────────────────────────────────────────────────────────────
enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, ATTACK, HURT, DEAD }
var state: State = State.IDLE

# ── Runtime vars ──────────────────────────────────────────────────────────────
var health: int
var facing: int = 1          # 1 = right, -1 = left

var jump_count: int = 0
var jumps_allowed: int = 2   # ground jump + one air jump

var coyote_active: bool = false
var jump_buffered: bool = false
var jump_buffer_timer: float = 0.0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true

var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var attack_direction: Vector2 = Vector2.ZERO

var is_hurt: bool = false
var hurt_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

var invincible: bool = false
var invincibility_timer: float = 0.0

var wall_jump_locked: bool = false
var wall_jump_lock_timer: float = 0.0

var _was_on_floor: bool = false

var gravity: float

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	health = stats.max_health
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

	hurtbox.owner_node = self
	hurtbox.hurt.connect(_on_hurt)

	for hb: Hitbox in [hitbox_right, hitbox_left, hitbox_up, hitbox_down]:
		hb.owner_node = self
		hb.hit_confirmed.connect(_on_hitbox_hit.bind(hb))

	coyote_timer.timeout.connect(_on_coyote_timer_timeout)
	coyote_timer.wait_time = stats.coyote_time
	coyote_timer.one_shot = true

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_tick_timers(delta)
	_handle_input(delta)
	_apply_gravity(delta)
	_apply_movement(delta)
	move_and_slide()
	_update_state()
	_update_animation()

# ── Timer ticks ───────────────────────────────────────────────────────────────
func _tick_timers(delta: float) -> void:
	if jump_buffered:
		jump_buffer_timer -= delta
		if jump_buffer_timer <= 0.0:
			jump_buffered = false

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			_end_dash()

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0.0:
			can_dash = true

	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_end_attack()

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			is_hurt = false
			knockback_velocity = Vector2.ZERO

	if invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			invincible = false
			hurtbox.invincible = false
			sprite.modulate.a = 1.0

	if wall_jump_locked:
		wall_jump_lock_timer -= delta
		if wall_jump_lock_timer <= 0.0:
			wall_jump_locked = false

# ── Input ─────────────────────────────────────────────────────────────────────
func _handle_input(_delta: float) -> void:
	if is_hurt or is_dashing:
		return

	var h := Input.get_axis("move_left", "move_right")
	if not wall_jump_locked and h != 0.0:
		facing = int(sign(h))
		sprite.flip_h = facing == -1

	if Input.is_action_just_pressed("jump"):
		_try_jump()
	elif Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= stats.jump_cut_multiplier

	if Input.is_action_just_pressed("dash") and can_dash:
		_start_dash()

	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0.0:
		_start_attack()

# ── Jump ──────────────────────────────────────────────────────────────────────
func _try_jump() -> void:
	if is_on_floor() or coyote_active:
		_do_jump(stats.jump_velocity)
		coyote_active = false
		coyote_timer.stop()
	elif _is_touching_wall() and not is_on_floor():
		_do_wall_jump()
	elif jump_count < jumps_allowed:
		_do_jump(stats.double_jump_velocity)
	else:
		jump_buffered = true
		jump_buffer_timer = stats.jump_buffer_time

func _do_jump(jump_vel: float) -> void:
	velocity.y = jump_vel
	jump_count += 1

func _do_wall_jump() -> void:
	var wall_dir: int = -1 if wall_ray_left.is_colliding() else 1
	velocity.x = stats.wall_jump_velocity.x * wall_dir
	velocity.y = stats.wall_jump_velocity.y
	facing = wall_dir
	sprite.flip_h = facing == -1
	wall_jump_locked = true
	wall_jump_lock_timer = stats.wall_jump_lock_time
	jump_count = 1

func _on_coyote_timer_timeout() -> void:
	coyote_active = false

func _activate_coyote() -> void:
	coyote_active = true
	coyote_timer.start(stats.coyote_time)

# ── Gravity ───────────────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if is_on_floor() or is_dashing:
		return
	var g := gravity * stats.gravity_scale
	if velocity.y > 0.0:
		g *= stats.fall_gravity_multiplier
	velocity.y = min(velocity.y + g * delta, stats.max_fall_speed)

# ── Movement ──────────────────────────────────────────────────────────────────
func _apply_movement(delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * stats.dash_speed
		return

	if is_hurt:
		velocity.x = knockback_velocity.x
		return

	var h := Input.get_axis("move_left", "move_right")
	var target_speed := h * stats.move_speed

	if h != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, stats.acceleration * delta)
	else:
		var fric := stats.friction if is_on_floor() else stats.air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	# Wall slide caps fall speed
	if _is_touching_wall() and not is_on_floor() and velocity.y > 0.0:
		velocity.y = min(velocity.y, stats.wall_slide_speed)

	# Consume buffered jump on landing
	if is_on_floor() and jump_buffered:
		jump_buffered = false
		_do_jump(stats.jump_velocity)

# ── Dash ──────────────────────────────────────────────────────────────────────
func _start_dash() -> void:
	var h := Input.get_axis("move_left", "move_right")
	var v := Input.get_axis("move_up",   "move_down")
	dash_direction = Vector2(h, v)
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2(float(facing), 0.0)
	else:
		dash_direction = dash_direction.normalized()

	is_dashing = true
	dash_timer = stats.dash_duration
	can_dash = false
	dash_cooldown_timer = stats.dash_cooldown

	if stats.dash_invincible:
		_set_invincible(stats.dash_duration + 0.05)

	if dash_trail:
		dash_trail.emitting = true

func _end_dash() -> void:
	is_dashing = false
	velocity.x = clamp(velocity.x, -stats.move_speed, stats.move_speed)
	if dash_trail:
		dash_trail.emitting = false

# ── Attack ────────────────────────────────────────────────────────────────────
func _start_attack() -> void:
	is_attacking = true
	attack_timer = stats.attack_duration
	attack_cooldown_timer = stats.attack_cooldown

	var v_axis := Input.get_axis("move_up", "move_down")
	if Input.is_action_pressed("attack_up") or (not is_on_floor() and v_axis < -0.6):
		attack_direction = Vector2.UP
	elif Input.is_action_pressed("attack_down") and not is_on_floor():
		attack_direction = Vector2.DOWN
	else:
		attack_direction = Vector2(float(facing), 0.0)

	_refresh_hitboxes()
	_apply_attack_recoil()

func _refresh_hitboxes() -> void:
	hitbox_right.disable()
	hitbox_left.disable()
	hitbox_up.disable()
	hitbox_down.disable()

	if attack_direction == Vector2.UP:
		hitbox_up.enable()
	elif attack_direction == Vector2.DOWN:
		hitbox_down.enable()
	elif attack_direction.x > 0.0:
		hitbox_right.enable()
	else:
		hitbox_left.enable()

func _apply_attack_recoil() -> void:
	if attack_direction == Vector2.UP:
		velocity.y = maxf(velocity.y, stats.knockback_force_dealt.y)
	elif attack_direction != Vector2.DOWN:
		velocity.x -= attack_direction.x * stats.knockback_force_dealt.x

func _end_attack() -> void:
	is_attacking = false
	hitbox_right.disable()
	hitbox_left.disable()
	hitbox_up.disable()
	hitbox_down.disable()

# Called via hit_confirmed signal; hb is bound as the second argument.
func _on_hitbox_hit(hurtbox_hit: Hurtbox, hb: Hitbox) -> void:
	hurtbox_hit.take_hit(hb)
	if attack_direction == Vector2.DOWN:
		velocity.y = stats.down_attack_bounce

# ── Hurt / knockback ──────────────────────────────────────────────────────────
func _on_hurt(damage: int, knockback_dir: Vector2, force_mult: float) -> void:
	health -= damage
	if health <= 0:
		_die()
		return

	is_hurt = true
	hurt_timer = stats.knockback_duration
	knockback_velocity = Vector2(
		knockback_dir.x * stats.knockback_force_received.x * force_mult,
		stats.knockback_force_received.y
	)
	velocity = knockback_velocity
	_set_invincible(stats.invincibility_duration)

func _die() -> void:
	health = 0
	_set_state(State.DEAD)

func _set_invincible(duration: float) -> void:
	invincible = true
	invincibility_timer = duration
	hurtbox.invincible = true

# ── State ─────────────────────────────────────────────────────────────────────
func _update_state() -> void:
	var on_floor := is_on_floor()

	if _was_on_floor and not on_floor and not is_dashing and velocity.y >= 0.0:
		_activate_coyote()

	if on_floor:
		jump_count = 0
		can_dash = true

	_was_on_floor = on_floor

	if state == State.DEAD or is_hurt or is_dashing or is_attacking:
		return

	if on_floor:
		_set_state(State.RUN if Input.get_axis("move_left", "move_right") != 0.0 else State.IDLE)
	elif _is_touching_wall() and velocity.y > 0.0:
		_set_state(State.WALL_SLIDE)
	elif velocity.y < 0.0:
		_set_state(State.JUMP)
	else:
		_set_state(State.FALL)

func _set_state(new_state: State) -> void:
	state = new_state

# ── Helpers ───────────────────────────────────────────────────────────────────
func _is_touching_wall() -> bool:
	return wall_ray_left.is_colliding() or wall_ray_right.is_colliding()

# ── Animation ─────────────────────────────────────────────────────────────────
func _update_animation() -> void:
	if invincible:
		sprite.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
	else:
		sprite.modulate.a = 1.0

	# Flip debug shape with facing direction
	if debug_shape:
		debug_shape.scale.x = float(facing)

	var anim := _pick_animation()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)

func _pick_animation() -> String:
	if state == State.DEAD:      return "death"
	if is_hurt:                  return "hurt"
	if is_dashing:               return "dash"
	if is_attacking:
		match attack_direction:
			Vector2.UP:          return "attack_up"
			Vector2.DOWN:        return "attack_down"
			_:                   return "attack"
	match state:
		State.RUN:               return "run"
		State.JUMP:              return "jump"
		State.FALL:              return "fall"
		State.WALL_SLIDE:        return "wall_slide"
	return "idle"
