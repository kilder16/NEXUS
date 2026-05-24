extends "res://scripts/ai/enemy.gd"

# === ENEMY FAST ===
# Rápido, frágil, golpea más fuerte.

func _ready():
	super._ready()
	health = 2
	max_health = 2
	display_name = "Asaltante"
	speed = 5.0
	chase_speed = 8.0
	attack_damage = 2
	base_color = Color(1.0, 0.85, 0.1)  # Amarillo
