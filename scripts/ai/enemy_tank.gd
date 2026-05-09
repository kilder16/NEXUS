extends "res://scripts/ai/enemy.gd"

# === ENEMY TANK ===
# Lento, mucha vida, daño normal.

func _ready():
	super._ready()
	health = 10
	speed = 1.25
	chase_speed = 2.0
	attack_damage = 1
	base_color = Color(0.2, 0.3, 0.6)  # Azul oscuro
