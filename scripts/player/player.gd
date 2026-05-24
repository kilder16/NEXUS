extends CharacterBody3D

# === MOVIMIENTO ===
var speed = 5.0
var jump_velocity = 4.5
var gravity = 9.8
var mouse_sensitivity = 0.002

# === VIDA ===
var max_health = 10
var health = 10
var is_dead: bool = false

# Y bajo el cual el player muere automáticamente (out-of-bounds / caer al vacío).
# Todos los pisos del juego están a Y≈0; -20 es ~20u debajo, imposible de
# alcanzar por mecánicas normales.
const FALL_DEATH_Y: float = -20.0

# === CONSTRUCCIÓN ===
var build_distance = 5.0
var current_block_type = 0
var block_types = ["Muro", "Rampa", "Plataforma"]

# === ARMAS ===
var weapons: Array = []
var current_weapon_index: int = 0
var shoot_cooldown: float = 0.0
var debug_shooting: bool = false  # poner true para logs por pellet

# === HUD INDICATOR ===
var enemy_indicator_max_distance: float = 40.0

# === REFERENCIAS ===
@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var hud = get_tree().current_scene.get_node("HUD")
@onready var game_over = get_tree().current_scene.get_node("GameOver")

# Precargar la escena del bloque
var block_scene = preload("res://scenes/building/block.tscn")

func _ready():
	add_to_group("player")
	setup_weapons()

	print("=== NEXUS - PLAYER INICIADO ===")
	print("Controles:")
	print("  WASD / Flechas = Mover")
	print("  Mouse = Mirar")
	print("  Espacio = Saltar")
	print("  Clic Izquierdo = Disparar / Destruir")
	print("  Clic Derecho = Construir bloque")
	print("  Q / E = Cambiar tipo de bloque")
	print("  1 / 2 / 3 = Cambiar arma")
	print("  R = Reiniciar nivel")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	await get_tree().process_frame
	update_hud()
	if hud:
		hud.show_message("Llega al objetivo verde", 3.0)

func setup_weapons():
	weapons = [
		Weapon.new("Pistola", 1, 0.2, 50.0),
		Weapon.new("Escopeta", 3, 0.8, 10.0, 0.12, 6),
		Weapon.new("Rifle", 2, 0.4, 100.0),
	]

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			build()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			current_block_type = (current_block_type - 1) % block_types.size()
			if current_block_type < 0:
				current_block_type = block_types.size() - 1
			update_hud()
		elif event.keycode == KEY_E:
			current_block_type = (current_block_type + 1) % block_types.size()
			update_hud()
		elif event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			switch_weapon(0)
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			switch_weapon(1)
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			switch_weapon(2)
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_H and debug_shooting:
			take_damage(1)

func switch_weapon(idx: int):
	if idx < 0 or idx >= weapons.size():
		return
	current_weapon_index = idx
	update_hud()
	if hud:
		hud.show_message("Arma: " + weapons[idx].weapon_name, 1.0)

func shoot():
	if shoot_cooldown > 0.0:
		return
	if weapons.is_empty():
		return

	var w: Weapon = weapons[current_weapon_index]
	shoot_cooldown = w.fire_rate
	AudioManager.play_sfx_pitched("shot")
	ParticleManager.spawn_muzzle_flash(
		camera.global_position - camera.global_transform.basis.z * 0.5,
		-camera.global_transform.basis.z
	)

	var space_state = get_world_3d().direct_space_state
	var origin: Vector3 = camera.global_position
	var base_forward: Vector3 = -camera.global_transform.basis.z
	var cam_x: Vector3 = camera.global_transform.basis.x
	var cam_y: Vector3 = camera.global_transform.basis.y

	for _i in w.pellets:
		var forward = base_forward
		if w.spread > 0.0:
			var sx = randf_range(-w.spread, w.spread)
			var sy = randf_range(-w.spread, w.spread)
			forward = forward.rotated(cam_x, sy).rotated(cam_y, sx).normalized()

		var to_pos = origin + forward * w.max_range
		var query = PhysicsRayQueryParameters3D.create(origin, to_pos)
		query.exclude = [self.get_rid()]
		var result = space_state.intersect_ray(query)
		if debug_shooting:
			print("[shoot] arma=", w.weapon_name, " pellet=", _i,
					" from=", origin, " to=", to_pos,
					" hit=", result.get("collider", null))
		if result:
			var target = result.collider
			if target and target.has_method("take_damage"):
				if debug_shooting:
					print("[shoot]   -> take_damage(", w.damage, ") en ", target.name)
				target.take_damage(w.damage)
				ParticleManager.spawn_blood(result.position)
			else:
				ParticleManager.spawn_impact(result.position, result.normal, "wall")

func build():
	if raycast.is_colliding():
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		
		var block_pos = Vector3(
			round(point.x + normal.x * 0.5),
			round(point.y + normal.y * 0.5),
			round(point.z + normal.z * 0.5)
		)
		
		if global_position.distance_to(block_pos) <= build_distance:
			place_block(block_pos)

func place_block(pos: Vector3):
	var block = block_scene.instantiate()
	block.global_position = pos
	block.block_type = current_block_type
	get_tree().current_scene.add_child(block)

func take_damage(amount: int):
	if is_dead:
		return
	AudioManager.play_sfx("hit", 0.0, 0.9)
	ParticleManager.show_damage_vignette()
	health -= amount
	print("¡DAÑO RECIBIDO! Vida: ", health, "/", max_health)
	update_hud()

	if hud:
		hud.show_message("¡DAÑO!", 0.3)

	if health <= 0:
		die()

func update_hud():
	if hud:
		hud.update_health(health, max_health)
		hud.update_block_type(current_block_type)
		if not weapons.is_empty():
			hud.update_weapon(weapons[current_weapon_index].weapon_name)

func _update_enemy_indicator():
	# Si el raycast (ya activo para build) está golpeando un enemigo dentro
	# del rango útil, pasamos la referencia al HUD; si no, pasamos null y
	# el HUD se fade-out.
	if not hud or not hud.has_method("update_enemy_indicator"):
		return
	var aimed: Node = null
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("enemy"):
			var distance: float = camera.global_position.distance_to(raycast.get_collision_point())
			if distance <= enemy_indicator_max_distance:
				aimed = collider
	hud.update_enemy_indicator(aimed)

func die():
	if is_dead:
		return
	is_dead = true
	AudioManager.play_sfx("enemy_death", 0.0, 0.8)
	print("=== HAS MUERTO ===")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if game_over:
		game_over.show_game_over()

func _physics_process(delta):
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity
	
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

	# Muerte por caer al vacío (fuera del polígono del piso).
	if not is_dead and global_position.y < FALL_DEATH_Y:
		die()

	_update_enemy_indicator()
