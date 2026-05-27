extends "res://scripts/ai/enemy_tank.gd"

# === BOSS FINAL ===
# Boss del nivel 5 (level_05). Extiende EnemyTank con stats propios y
# hooks para animaciones del modelo 3D Mixamo (a integrar).
# Visualmente diferenciado del Bastión genérico mediante escena dedicada
# boss_final.tscn.

func _ready() -> void:
	super._ready()
	# Stats overrideados acá (antes vivían en level_05.gd post-_ready).
	# Mejor encapsulación: el boss conoce sus propios stats.
	health = 50
	max_health = 50
	shield = 15
	max_shield = 15
	display_name = "JEFE: NÚCLEO"
	# El aura del shield se vuelve a sincronizar con el nuevo max_shield
	# (super._ready ya la inicializó en función del shield=4 del Bastión).
	if _shield_visual:
		_shield_visual.visible = shield > 0

func _on_state_changed(new_state: int) -> void:
	# Hook para animaciones — se rellena cuando integremos el
	# AnimationPlayer del modelo Mixamo (Día 7 Fase 4).
	pass

func _on_attack_trigger() -> void:
	# Hook para anim de ataque one-shot — idem.
	pass
