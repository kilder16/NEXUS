extends "res://scripts/ai/enemy.gd"

# === ENEMY TANK ===
# Lento, mucha vida, daño normal. Tiene escudo destructible (4 puntos)
# que absorbe daño antes que el HP base (8). Al romperse el escudo: VFX
# ruptura y el aura cyan se oculta.

const SHIELD_BREAK_SCENE: PackedScene = preload("res://scenes/effects/shield_break.tscn")

@onready var _shield_visual: Node3D = get_node_or_null("ShieldVisual")

func _ready():
	super._ready()
	health = 8
	max_health = 8
	shield = 4
	max_shield = 4
	display_name = "Bastión"
	speed = 1.25
	chase_speed = 2.0
	attack_damage = 1
	# El Centinela base pasó a ranged corto (attack_range = 6, cooldown 1.5).
	# El Bastión mantiene su melee original: rango 2.0 y cooldown 1.0.
	attack_range = 2.0
	attack_cooldown = 1.0
	base_color = Color(0.2, 0.3, 0.6)  # Azul oscuro
	# El aura arranca visible si tiene escudo, oculta si no.
	if _shield_visual:
		_shield_visual.visible = shield > 0

# El Centinela (base) ahora dispara proyectiles cortos cuando attack_timer expira.
# El Bastión preserva su patrón melee overrideando sólo _perform_attack.
func _perform_attack() -> void:
	if player == null:
		return
	print("¡BASTIÓN GOLPEA! Daño: ", attack_damage)
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func _on_shield_broken() -> void:
	if _shield_visual:
		_shield_visual.visible = false
	var fx: Node3D = SHIELD_BREAK_SCENE.instantiate()
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(fx)
		fx.global_position = global_position
