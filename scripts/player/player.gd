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

# Escenas de armas no-hitscan (granadas, cohetes, etc).
const GRENADE_SCENE: PackedScene = preload("res://scenes/weapons/grenade.tscn")
const ROCKET_SCENE: PackedScene = preload("res://scenes/weapons/rocket.tscn")
const MELEE_SLASH_SCENE: PackedScene = preload("res://scenes/effects/melee_slash.tscn")
# Parámetros de lanzamiento de granada (arco hacia donde apunta la cámara).
const GRENADE_THROW_FORCE: float = 12.0
const GRENADE_LIFT: float = 3.0
# Distancia del slash respecto a la cámara cuando se spawnea.
const MELEE_SLASH_FORWARD: float = 0.9
# Magnitud del kick de cámara al swing melee. ~1° hacia arriba, recovery rápido.
const MELEE_SHAKE_AMOUNT: float = 0.018
const MELEE_SHAKE_DURATION: float = 0.08

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
	print("  1..8 = Cambiar arma (slots disponibles según loadout)")
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
		# Slot 4: Granada. fire_rate 2.0s (cooldown entre lanzamientos),
		# max_ammo 3 (se resetea naturalmente en cada nivel vía _ready).
		Weapon.new("Granada", 0, 2.0, 0.0, 0.0, 1, 3, "grenade"),
		# Slot 5: Bazuca. fire_rate 1.5s, max_ammo 2 (cohete pega más fuerte
		# que la granada y es directo, así que es más limitada).
		Weapon.new("Bazuca", 0, 1.5, 0.0, 0.0, 1, 2, "rocket"),
	]
	# Slot 6: Cuchillo. Rápido (0.3s), daño 5, rango 2u. Munición infinita
	# (default). sfx/color asignados post-creación para no inflar _init.
	var knife: Weapon = Weapon.new("Cuchillo", 5, 0.3, 2.0, 0.0, 1, -1, "melee_swing")
	knife.sfx_name = "stab"
	knife.vfx_color = Color(1, 1, 1, 1)
	weapons.append(knife)

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
		elif event.keycode == KEY_4 or event.keycode == KEY_KP_4:
			switch_weapon(3)
		elif event.keycode == KEY_5 or event.keycode == KEY_KP_5:
			switch_weapon(4)
		elif event.keycode == KEY_6 or event.keycode == KEY_KP_6:
			switch_weapon(5)
		elif event.keycode == KEY_7 or event.keycode == KEY_KP_7:
			switch_weapon(6)
		elif event.keycode == KEY_8 or event.keycode == KEY_KP_8:
			switch_weapon(7)
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
	# Munición limitada (granadas, bazuca): si no queda, "click" vacío y abortar.
	if not w.has_ammo():
		AudioManager.play_sfx("empty_click")
		shoot_cooldown = 0.25  # pequeño debounce para que el click no spamme.
		return

	# Branchear por tipo. Cada handler aplica su efecto; el consumo de
	# munición y cooldown sucede acá para todos por igual.
	match w.type:
		"hitscan":
			_fire_hitscan(w)
		"grenade":
			_throw_grenade(w)
		"rocket":
			_fire_rocket(w)
		"melee_swing":
			do_melee_swing(w.damage, w.max_range, w.sfx_name, w.vfx_color)
		_:
			push_warning("Tipo de arma no soportado todavía: " + w.type)
			return

	w.consume_ammo()
	if w.has_limited_ammo():
		update_hud()
	shoot_cooldown = w.fire_rate

func _fire_hitscan(w: Weapon) -> void:
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

func _throw_grenade(_w: Weapon) -> void:
	var grenade: RigidBody3D = GRENADE_SCENE.instantiate()
	get_tree().current_scene.add_child(grenade)
	# Spawn justo delante de la cámara para no chocar consigo mismo en el primer frame.
	var forward: Vector3 = -camera.global_transform.basis.z
	grenade.global_position = camera.global_position + forward * 0.6
	# Velocidad inicial: empuje hacia adelante + lift para que el arco
	# sea visible en distancia media.
	grenade.linear_velocity = forward * GRENADE_THROW_FORCE + Vector3.UP * GRENADE_LIFT
	AudioManager.play_sfx_pitched("shot")

func _fire_rocket(_w: Weapon) -> void:
	var rocket: Area3D = ROCKET_SCENE.instantiate()
	get_tree().current_scene.add_child(rocket)
	# Spawn delante de la cámara y a la altura del cañón (~0.6u adelante).
	var forward: Vector3 = -camera.global_transform.basis.z
	rocket.global_position = camera.global_position + forward * 0.8
	rocket.direction = forward
	rocket.shooter = self
	AudioManager.play_sfx_pitched("shot")

# Swing melee compartido por cuchillo / hacha / sierra (3.2, 3.3, 3.4).
# El raycast es corto desde la cámara; si pega a algo con take_damage,
# aplica daño y partículas de impacto. SFX + slash visual + kick de cámara.
func do_melee_swing(damage: int, range_: float, sfx_name: String, vfx_color: Color) -> void:
	# 1) Raycast corto desde la cámara para detectar el primer impacto.
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * range_)
	query.exclude = [self.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		var target: Node = result.collider
		if target and target.has_method("take_damage"):
			target.take_damage(damage)
			ParticleManager.spawn_blood(result.position)
		else:
			ParticleManager.spawn_impact(result.position, result.normal, "wall")

	# 2) SFX (si el caller pasó uno).
	if sfx_name != "":
		AudioManager.play_sfx_pitched(sfx_name)

	# 3) Slash visual delante de la cámara, encarado en su dirección.
	var slash: Node3D = MELEE_SLASH_SCENE.instantiate()
	get_tree().current_scene.add_child(slash)
	slash.global_position = camera.global_position + forward * MELEE_SLASH_FORWARD
	# Alinear el quad a la cámara: mismo basis, su normal queda hacia el player.
	slash.global_transform.basis = camera.global_transform.basis
	if slash.has_method("play"):
		slash.play(vfx_color)

	# 4) Kick de cámara breve.
	_camera_shake_pulse(MELEE_SHAKE_AMOUNT, MELEE_SHAKE_DURATION)

func _camera_shake_pulse(amount: float = 0.02, duration: float = 0.08) -> void:
	# Pulse muy breve: pisa rotation.x durante ~80ms. Si el mouse se está
	# moviendo, el drift es despreciable (< 1 frame de input).
	if camera == null:
		return
	var base_x: float = camera.rotation.x
	var peak_x: float = clamp(base_x - amount, -1.5, 1.5)
	var t: Tween = create_tween()
	t.tween_property(camera, "rotation:x", peak_x, duration * 0.4)
	t.tween_property(camera, "rotation:x", base_x, duration * 0.6)

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
			var w: Weapon = weapons[current_weapon_index]
			hud.update_weapon(w.weapon_name, current_weapon_index, weapons.size())
			hud.update_ammo(w.ammo, w.max_ammo)

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
