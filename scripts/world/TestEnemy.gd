extends Enemy
class_name TestEnemy

# A simple walker enemy for testing the combat system.
# Patrols until it sees the player, then chases and attacks.

func _ready() -> void:
	super._ready()
	max_health = 3
	patrol_speed = 50.0
	chase_speed = 90.0
	attack_range = 35.0
	attack_cooldown = 1.5
	health = max_health
