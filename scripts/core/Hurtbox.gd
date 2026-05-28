extends Area2D
class_name Hurtbox

signal hurt(damage: int, knockback_direction: Vector2, knockback_force: float)

var owner_node: Node = null
var invincible: bool = false

func take_hit(hitbox: Hitbox) -> void:
	if invincible:
		return
	var dir := hitbox.knockback_direction
	if dir == Vector2.ZERO:
		# auto-calculate: push away from hitbox origin
		dir = (global_position - hitbox.global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
	hurt.emit(hitbox.damage, dir, hitbox.knockback_force)
