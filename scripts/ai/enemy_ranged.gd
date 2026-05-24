extends "res://scripts/ai/enemy.gd"

# === ENEMY RANGED ===
# Vida media, dispara proyectiles desde lejos y mantiene distancia.

@export var projectile_scene: PackedScene
var preferred_distance = 8.0

func _ready():
	super._ready()
	health = 4
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
		# Demasiado cerca: retroceder manteniendo la mira
		velocity.x = -direction.x * chase_speed
		velocity.z = -direction.z * chase_speed
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
	if projectile_scene == null:
		push_warning("EnemyRanged: projectile_scene no asignado en el inspector")
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	# Spawn ligeramente delante para no colisionar consigo mismo
	var spawn_offset = (player.global_position - global_position).normalized() * 1.2
	spawn_offset.y = 0.5
	projectile.global_position = global_position + spawn_offset

	projectile.direction = (player.global_position - projectile.global_position).normalized()
	projectile.shooter = self
	projectile.damage = attack_damage

	print("¡ENEMY RANGED DISPARA!")
