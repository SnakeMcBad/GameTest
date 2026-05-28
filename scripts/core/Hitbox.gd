extends Area2D
class_name Hitbox

signal hit_confirmed(hurtbox: Hurtbox)

@export var damage: int = 1
## Zero = auto-calculate direction from relative positions.
@export var knockback_direction: Vector2 = Vector2.ZERO
@export var knockback_force: float = 1.0

var owner_node: Node = null

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)

func enable() -> void:
	monitoring = true

func disable() -> void:
	monitoring = false

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.owner_node != owner_node:
		hit_confirmed.emit(area)
