extends CharacterBody2D
class_name Enemy

# ── Signals ───────────────────────────────────────────────────────────────────
signal died

# ── References ────────────────────────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D  = $AnimatedSprite2D
@onready var hurtbox: Hurtbox          = $Hurtbox
@onready var hitbox: Hitbox            = $Hitbox
@onready var detection_area: Area2D    = $DetectionArea
@onready var wall_ray: RayCast2D       = $WallRay
@onready var edge_ray: RayCast2D       = $EdgeRay

# ── Stats (override in subclass or inspector) ─────────────────────────────────
@export var max_health: int = 3
@export var move_speed: float = 80.0
@export var patrol_speed: float = 60.0
@export var chase_speed: float = 110.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.2
@export var knockback_force_received: Vector2 = Vector2(200.0, -150.0)
@export var knockback_duration: float = 0.3
@export var invincibility_duration: float = 0.4

# ── State machine ─────────────────────────────────────────────────────────────
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state: State = State.PATROL

# ── Runtime vars ──────────────────────────────────────────────────────────────
var health: int
var facing: int = 1
var target: Node2D = null

var is_hurt: bool = false
var hurt_timer: float = 0.0
var invincible: bool = false
var invincibility_timer: float = 0.0

var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

var gravity: float

func _ready() -> void:
	health = max_health
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

	hurtbox.owner_node = self
	hurtbox.hurt.connect(_on_hurt)

	hitbox.owner_node = self
	hitbox.damage = 1
	hitbox.disable()

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_tick_timers(delta)
	_apply_gravity(delta)
	_think(delta)
	move_and_slide()
	_update_animation()

func _tick_timers(delta: float) -> void:
	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			is_hurt = false

	if invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			invincible = false
			hurtbox.invincible = false

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if state == State.ATTACK:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_end_attack()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 900.0)

# ── AI behaviour (override in subclasses for custom logic) ────────────────────
func _think(delta: float) -> void:
	if is_hurt or state == State.ATTACK:
		return

	match state:
		State.PATROL: _do_patrol(delta)
		State.CHASE:  _do_chase(delta)

func _do_patrol(_delta: float) -> void:
	if _should_turn():
		_flip()
	velocity.x = facing * patrol_speed

func _do_chase(_delta: float) -> void:
	if target == null:
		_set_state(State.PATROL)
		return

	var dist := global_position.distance_to(target.global_position)
	if dist <= attack_range and attack_cooldown_timer <= 0.0:
		_start_attack()
		return

	var dir: float = sign(target.global_position.x - global_position.x)
	if dir != 0:
		facing = int(dir)
		sprite.flip_h = facing == -1
	velocity.x = facing * chase_speed

func _should_turn() -> bool:
	var hit_wall := wall_ray.is_colliding()
	var at_edge  := not edge_ray.is_colliding()
	return hit_wall or at_edge

func _flip() -> void:
	facing *= -1
	sprite.flip_h = facing == -1
	wall_ray.target_position.x  *= -1
	edge_ray.position.x         *= -1

# ── Attack ────────────────────────────────────────────────────────────────────
func _start_attack() -> void:
	_set_state(State.ATTACK)
	attack_timer = 0.4
	attack_cooldown_timer = attack_cooldown
	velocity.x = 0.0
	hitbox.enable()

func _end_attack() -> void:
	hitbox.disable()
	_set_state(State.CHASE if target != null else State.PATROL)

# ── Hurt / death ──────────────────────────────────────────────────────────────
func _on_hurt(damage: int, knockback_dir: Vector2, force_mult: float) -> void:
	health -= damage
	if health <= 0:
		_die()
		return

	is_hurt = true
	hurt_timer = knockback_duration
	velocity = Vector2(
		knockback_dir.x * knockback_force_received.x * force_mult,
		knockback_force_received.y
	)
	invincible = true
	invincibility_timer = invincibility_duration
	hurtbox.invincible = true
	_set_state(State.HURT)

func _die() -> void:
	health = 0
	_set_state(State.DEAD)
	hitbox.disable()
	died.emit()
	# Subclass can override to add death effects before queue_free
	queue_free()

# ── Detection ─────────────────────────────────────────────────────────────────
func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		target = body
		_set_state(State.CHASE)

func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		_set_state(State.PATROL)

# ── State ─────────────────────────────────────────────────────────────────────
func _set_state(new_state: State) -> void:
	state = new_state

# ── Animation (override per enemy type) ───────────────────────────────────────
func _update_animation() -> void:
	var anim := _pick_animation()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)

func _pick_animation() -> String:
	if state == State.DEAD:   return "death"
	if is_hurt:               return "hurt"
	if state == State.ATTACK: return "attack"
	if abs(velocity.x) > 5.0: return "run"
	return "idle"
