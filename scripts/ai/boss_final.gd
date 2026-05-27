extends "res://scripts/ai/enemy_tank.gd"

# === BOSS FINAL ===
# Boss del nivel 5 (level_05). Extiende EnemyTank con stats propios y
# animaciones del modelo 3D Mixamo (Swat Guy) cargado vía boss.glb.
# Visualmente diferenciado del Bastión genérico mediante escena dedicada
# boss_final.tscn.

var anim_player: AnimationPlayer = null

func _ready() -> void:
	super._ready()
	# Stats overrideados acá (antes vivían en level_05.gd post-_ready).
	# Mejor encapsulación: el boss conoce sus propios stats.
	health = 50
	max_health = 50
	shield = 15
	max_shield = 15
	display_name = "JEFE: NÚCLEO"
	# Tuning final de bruiser melee: más amenazante que un Bastión genérico
	# (que tiene attack_damage=1, cooldown=1.0, chase_speed=2.0). El boss
	# pega más fuerte, persigue mucho más rápido (7.0 vs 2.0) y tiene
	# mayor alcance de swing (3.5 vs 2.0). Stickiness queda en defaults de
	# enemy.gd (no se override settle/exit_factor/slowdown).
	attack_damage = 4
	attack_cooldown = 1.0
	attack_range = 3.5
	chase_speed = 7.0
	speed = 0.8
	detect_range = 8.0
	# Override patrol_points: cuadrado de 12x12u centrado en el spawn del
	# boss (vs default 6x3u auto-generado en enemy.gd). Combinado con
	# speed=0.8 y patrol_wait_time=0.5, el boss patrulla un área grande
	# sin parar demasiado en cada esquina.
	patrol_points.clear()
	var origin: Vector3 = global_position
	patrol_points.append(origin + Vector3(6, 0, 0))
	patrol_points.append(origin + Vector3(6, 0, 6))
	patrol_points.append(origin + Vector3(-6, 0, 6))
	patrol_points.append(origin + Vector3(-6, 0, 0))
	patrol_wait_time = 0.5
	# El aura del shield se vuelve a sincronizar con el nuevo max_shield
	# (super._ready ya la inicializó en función del shield=4 del Bastión).
	if _shield_visual:
		_shield_visual.visible = shield > 0

	# Buscar el AnimationPlayer del modelo Swat. Lo hacemos recursivo
	# (en lugar de hardcodear el path "$SwatModel/boss/AnimationPlayer")
	# para no depender del nombre exacto del nodo raíz del GLB importado
	# por Godot, que puede variar según el archivo Mixamo.
	var swat_model: Node = get_node_or_null("SwatModel")
	if swat_model:
		anim_player = _find_animation_player(swat_model)

	# Animación inicial: idle si existe en el AnimationPlayer del modelo.
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

# Búsqueda recursiva en el árbol del nodo dado. Devuelve el primer
# AnimationPlayer que encuentre o null si no hay.
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result:
			return result
	return null

# Hook llamado por enemy.gd::set_state al cambiar de estado. Mapea cada
# estado del AI a la animación correspondiente del modelo Mixamo.
func _on_state_changed(new_state: State) -> void:
	if not anim_player:
		return
	match new_state:
		State.PATROL:
			if anim_player.has_animation("walk"):
				anim_player.play("walk")
		State.CHASE:
			if anim_player.has_animation("walk"):
				anim_player.play("walk")
		State.ATTACK:
			if anim_player.has_animation("attack"):
				anim_player.play("attack")
		State.DEAD:
			if anim_player.has_animation("death"):
				anim_player.play("death")

func _on_attack_trigger() -> void:
	# Llamado por enemy_tank.gd::_perform_attack en CADA hit del boss
	# (no solo al entrar al estado ATTACK). Reinicia la animación attack
	# desde el frame 0 para que el swing se reproduzca completo en cada
	# golpe, en vez de quedarse congelada después del primer hit.
	if anim_player and anim_player.has_animation("attack"):
		anim_player.stop()
		anim_player.play("attack")

# Override de enemy.gd::do_chase para agregar criterio "player muy lejos
# del boss": si el player se aleja más de 10u del boss, abandona el chase
# y vuelve a PATROL. No usa ARENA fija; el corte es relativo al boss.
func do_chase(_delta):
	if player == null:
		set_state(State.PATROL)
		return

	# Si el player se alejó mucho del boss, dejar de perseguir.
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player > 10.0:
		set_state(State.PATROL)
		return

	var to_player = player.global_position - global_position
	to_player.y = 0
	var distance = to_player.length()

	if distance < attack_range:
		set_state(State.ATTACK)
		_attack_settle_timer = attack_settle_time
		attack_timer = 0.0
		velocity.x = 0
		velocity.z = 0
	else:
		var direction = to_player.normalized()
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed
		look_at(global_position + direction, Vector3.UP)
