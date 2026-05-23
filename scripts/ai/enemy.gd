extends CharacterBody3D

signal died(enemy: Node)

# === STATS ===
var health = 3
var speed = 2.5
var chase_speed = 4.0
var attack_damage = 1
var attack_range = 2.0
var detect_range = 10.0
var attack_cooldown = 1.0
var base_color = Color(0.8, 0.1, 0.1)

# === PATRULLA ===
var patrol_points: Array[Vector3] = []
var current_patrol_index = 0
var patrol_wait_time = 2.0
var patrol_timer = 0.0
var waiting = false

# === ESTADO ===
enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state = State.PATROL
var gravity = 9.8
var attack_timer = 0.0

# === REFERENCIAS ===
var player = null

func _ready():
	# Buscar al jugador
	player = get_tree().get_first_node_in_group("player")
	
	# Si no hay puntos de patrulla, crear algunos alrededor de la posición inicial
	if patrol_points.size() == 0:
		var origin = global_position
		patrol_points.append(origin + Vector3(3, 0, 0))
		patrol_points.append(origin + Vector3(3, 0, 3))
		patrol_points.append(origin + Vector3(-3, 0, 3))
		patrol_points.append(origin + Vector3(-3, 0, 0))

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Actualizar cooldown de ataque
	if attack_timer > 0:
		attack_timer -= delta
	
	# Máquina de estados
	match current_state:
		State.PATROL:
			do_patrol(delta)
		State.CHASE:
			do_chase(delta)
		State.ATTACK:
			do_attack(delta)
		State.DEAD:
			return
	
	# Verificar si puede ver al jugador
	if current_state != State.DEAD:
		check_player_distance()
	
	move_and_slide()

func do_patrol(delta):
	if patrol_points.size() == 0:
		return
	
	if waiting:
		patrol_timer -= delta
		if patrol_timer <= 0:
			waiting = false
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		return
	
	var target = patrol_points[current_patrol_index]
	var direction = (target - global_position)
	direction.y = 0  # Solo moverse en horizontal
	
	if direction.length() < 0.5:
		# Llegó al punto, esperar
		waiting = true
		patrol_timer = patrol_wait_time
		velocity.x = 0
		velocity.z = 0
	else:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# Mirar hacia donde camina
		look_at(global_position + direction, Vector3.UP)

func do_chase(delta):
	if player == null:
		current_state = State.PATROL
		return
	
	var direction = (player.global_position - global_position)
	direction.y = 0
	
	if direction.length() < attack_range:
		current_state = State.ATTACK
		velocity.x = 0
		velocity.z = 0
	else:
		direction = direction.normalized()
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed
		look_at(global_position + direction, Vector3.UP)

func do_attack(delta):
	if player == null:
		current_state = State.PATROL
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance > attack_range * 1.5:
		current_state = State.CHASE
		return
	
	# Mirar al jugador
	var direction = (player.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.1:
		look_at(global_position + direction.normalized(), Vector3.UP)
	
	# Atacar si el cooldown terminó
	if attack_timer <= 0:
		attack_timer = attack_cooldown
		print("¡ENEMIGO ATACA! Daño: ", attack_damage)
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

func check_player_distance():
	if player == null:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if current_state == State.PATROL and distance < detect_range:
		current_state = State.CHASE
		print("¡ENEMIGO TE DETECTÓ!")
	elif current_state == State.CHASE and distance > detect_range * 1.5:
		current_state = State.PATROL
		print("Enemigo perdió al jugador")

func take_damage(amount: int = 1):
	if current_state == State.DEAD:
		return
	AudioManager.play_sfx_pitched("hit")
	health -= amount
	print("Enemigo recibió daño (", amount, "). Vida: ", health)
	
	if health <= 0:
		die()
	else:
		# Flashear rojo al recibir daño
		flash_damage()

func flash_damage():
	var mesh = $MeshInstance3D
	if mesh:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 1, 1)  # Blanco por un momento
		mesh.material_override = material
		# Restaurar color después de 0.1 segundos
		await get_tree().create_timer(0.1).timeout
		material.albedo_color = base_color
		mesh.material_override = material

func die():
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	died.emit(self)
	AudioManager.play_sfx("enemy_death")
	ParticleManager.spawn_enemy_death(global_position)
	print("¡ENEMIGO ELIMINADO!")
	# Animación simple de muerte
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(queue_free)
