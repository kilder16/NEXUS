extends CharacterBody3D

# === MOVIMIENTO ===
var speed = 5.0
var jump_velocity = 4.5
var gravity = 9.8
var mouse_sensitivity = 0.002

# === VIDA ===
var max_health = 10
var health = 10

# === CONSTRUCCIÓN ===
var build_distance = 5.0
var current_block_type = 0
var block_types = ["Muro", "Rampa", "Plataforma"]

# === REFERENCIAS ===
@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var hud = get_tree().current_scene.get_node("HUD")
@onready var game_over = get_tree().current_scene.get_node("GameOver")

# Precargar la escena del bloque
var block_scene = preload("res://scenes/building/block.tscn")

func _ready():
	add_to_group("player")
	
	print("=== NEXUS - PLAYER INICIADO ===")
	print("Controles:")
	print("  WASD / Flechas = Mover")
	print("  Mouse = Mirar")
	print("  Espacio = Saltar")
	print("  Clic Izquierdo = Disparar / Destruir")
	print("  Clic Derecho = Construir bloque")
	print("  Q / E = Cambiar tipo de bloque")
	print("  R = Reiniciar nivel")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	update_hud()
	if hud:
		hud.show_message("Llega al objetivo verde", 3.0)

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
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()

func shoot():
	if raycast.is_colliding():
		var target = raycast.get_collider()
		
		if target.has_method("take_damage"):
			target.take_damage()

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

func die():
	print("=== HAS MUERTO ===")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if game_over:
		game_over.show_game_over()

func _physics_process(delta):
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
