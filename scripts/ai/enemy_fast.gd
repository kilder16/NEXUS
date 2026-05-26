extends "res://scripts/ai/enemy.gd"

# === ENEMY FAST ===
# Rápido, frágil, golpea más fuerte. Melee: carga al player y pega.

func _ready():
	super._ready()
	health = 2
	max_health = 2
	display_name = "Asaltante"
	speed = 5.0
	chase_speed = 8.0
	attack_damage = 2
	# El Centinela (base) pasó a ranged corto (range 6, cooldown 1.5). El
	# Asaltante mantiene melee original: rango 2.0 y cooldown 1.0.
	attack_range = 2.0
	attack_cooldown = 1.0
	# Anti-rebote ATTACK↔CHASE: con chase_speed=8 el Asaltante sobrepasa
	# al player y vuelve a CHASE antes de que attack_timer llegue a 0,
	# así que solo el primer hit se aplicaba.
	# - exit_factor 2.5 (vs default 1.5) → más sticky en ATTACK.
	# - settle 0.15s → garantiza ≥1 hit por entrada al estado.
	# - slowdown a 4u → frena al acercarse, evita overshoot.
	attack_exit_factor = 2.5
	attack_settle_time = 0.15
	proximity_slowdown_distance = 4.0
	base_color = Color(1.0, 0.85, 0.1)  # Amarillo

# Preserva el patrón melee del Asaltante (la base ahora dispara proyectiles cortos).
func _perform_attack() -> void:
	if player == null:
		return
	print("¡ASALTANTE GOLPEA! Daño: ", attack_damage)
	if player.has_method("take_damage"):
		player.take_damage(attack_damage, global_position)
