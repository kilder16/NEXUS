extends "res://scripts/ai/enemy.gd"

# === ENEMY RANGED ===
# Vida media, dispara proyectiles desde lejos y mantiene distancia.

# Escena del proyectil precargada (antes era @export sin asignación en el
# .tscn → el Tirador nunca disparó desde v1.0 hasta v1.1). Mismo patrón que
# enemy.gd::PROJECTILE_SHORT_SCENE para evitar el problema en el futuro.
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/projectile.tscn")
var preferred_distance = 8.0

func _ready():
	super._ready()
	health = 4
	max_health = 4
	display_name = "Tirador"
	attack_range = 12.0
	detect_range = 15.0
	attack_cooldown = 1.5
	base_color = Color(0.6, 0.2, 0.8)  # Púrpura

func do_chase(_delta):
	if player == null:
		current_state = State.PATROL
		return

	var to_player = player.global_position - global_position
	to_player.y = 0
	var distance = to_player.length()

	# Dentro de rango de tiro y no demasiado cerca → atacar
	if distance <= attack_range and distance >= preferred_distance * 0.7:
		current_state = State.ATTACK
		velocity.x = 0
		velocity.z = 0
		return

	var direction = to_player.normalized()

	if distance < preferred_distance * 0.7:
		# Demasiado cerca: intentar retroceder, pero sólo si hay piso atrás.
		# Antes el Tirador se tiraba al vacío arrinconado contra el borde
		# (task #4 Día 5). Raycast desde ~2u atrás + 0.5u arriba hacia
		# Vector3.DOWN * 3u: si no encuentra piso, nos quedamos quietos
		# disparando desde la posición actual.
		var retreat_dir: Vector3 = -direction
		var probe_pos: Vector3 = global_position + retreat_dir * 2.0 + Vector3.UP * 0.5
		var probe_end: Vector3 = probe_pos + Vector3.DOWN * 3.0
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var probe_query := PhysicsRayQueryParameters3D.create(probe_pos, probe_end)
		probe_query.exclude = [self.get_rid()]
		var ground_check: Dictionary = space_state.intersect_ray(probe_query)
		if ground_check:
			velocity.x = retreat_dir.x * chase_speed
			velocity.z = retreat_dir.z * chase_speed
		else:
			# Sin piso atrás: quedarse parado y disparar igual desde acá.
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed

	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)

func do_attack(_delta):
	if player == null:
		current_state = State.PATROL
		return

	var to_player = player.global_position - global_position
	to_player.y = 0
	var distance = to_player.length()

	if distance > attack_range or distance < preferred_distance * 0.7:
		current_state = State.CHASE
		return

	var direction = to_player.normalized()
	look_at(global_position + direction, Vector3.UP)

	if attack_timer <= 0:
		attack_timer = attack_cooldown
		shoot_projectile()

func shoot_projectile():
	var projectile = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)

	# Spawn ligeramente delante para no colisionar consigo mismo
	var spawn_offset = (player.global_position - global_position).normalized() * 1.2
	spawn_offset.y = 0.5
	projectile.global_position = global_position + spawn_offset

	projectile.direction = (player.global_position - projectile.global_position).normalized()
	projectile.shooter = self
	projectile.damage = attack_damage

	print("¡ENEMY RANGED DISPARA!")
