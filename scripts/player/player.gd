extends CharacterBody3D

# === MOVIMIENTO ===
var speed = 5.0
var jump_velocity = 4.5
var gravity = 9.8
var mouse_sensitivity = 0.002

# === CONSTRUCCIÓN ===
var build_distance = 5.0  # Distancia máxima para construir
var current_block_type = 0  # Tipo de bloque seleccionado
var block_types = ["Muro", "Rampa", "Plataforma"]

# === REFERENCIAS ===
@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D

# Precargar la escena del bloque
var block_scene = preload("res://scenes/building/block.tscn")

func _ready():
	print("=== NEXUS - PLAYER INICIADO ===")
	print("Controles:")
	print("  WASD / Flechas = Mover")
	print("  Mouse = Mirar")
	print("  Espacio = Saltar")
	print("  Clic Izquierdo = Disparar / Destruir")
	print("  Clic Derecho = Construir bloque")
	print("  Q / E = Cambiar tipo de bloque")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# ESC para liberar mouse
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Capturar mouse al hacer clic
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
	
	# Rotación con mouse
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)
	
	# DISPARO / DESTRUIR con clic izquierdo
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			shoot()
		# CONSTRUIR con clic derecho
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			build()
	
	# Cambiar tipo de bloque con Q y E
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			current_block_type = (current_block_type - 1) % block_types.size()
			if current_block_type < 0:
				current_block_type = block_types.size() - 1
			print("Bloque seleccionado: ", block_types[current_block_type])
		elif event.keycode == KEY_E:
			current_block_type = (current_block_type + 1) % block_types.size()
			print("Bloque seleccionado: ", block_types[current_block_type])

func shoot():
	print("¡DISPARO!")
	if raycast.is_colliding():
		var target = raycast.get_collider()
		var point = raycast.get_collision_point()
		print("Impacto en: ", target.name)
		
		# Si el objeto tiene take_damage, destruirlo
		if target.has_method("take_damage"):
			target.take_damage()

func build():
	if raycast.is_colliding():
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		
		# Calcular posición del bloque (alineado a grilla de 1 metro)
		var block_pos = Vector3(
			round(point.x + normal.x * 0.5),
			round(point.y + normal.y * 0.5),
			round(point.z + normal.z * 0.5)
		)
		
		# Verificar distancia
		if global_position.distance_to(block_pos) <= build_distance:
			place_block(block_pos)
		else:
			print("Muy lejos para construir")
	else:
		print("Apunta a una superficie para construir")

func place_block(pos: Vector3):
	# Crear instancia del bloque
	var block = block_scene.instantiate()
	block.global_position = pos
	block.block_type = current_block_type
	
	# Agregar al nivel
	get_tree().current_scene.add_child(block)
	print("Bloque colocado en: ", pos, " - Tipo: ", block_types[current_block_type])

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Salto
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity
	
	# Input de movimiento
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	# Convertir a dirección 3D relativa a donde mira
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()
