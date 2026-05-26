extends CharacterBody3D

# === MOVIMIENTO ===
var speed = 5.0
var jump_velocity = 4.5
var gravity = 9.8
var mouse_sensitivity = 0.002

# Doble salto: una segunda activación de salto en aire. Se consume al usarlo
# y se resetea al tocar piso. _space_held_prev trackea el edge del input
# para que el segundo salto requiera soltar y volver a apretar SPACE
# (evita rebote auto si SPACE sigue held al saltar el primero).
var has_double_jumped: bool = false
var _space_held_prev: bool = false
const DOUBLE_JUMP_VELOCITY_FACTOR: float = 0.9

# Recoil acumulado: magnitud positiva en radianes que indica cuánto la
# cámara está "extra arriba" respecto a la rotation que setea el mouse.
# Decae cada frame en _physics_process aplicando un delta proporcional
# a camera.rotation.x (la baja). Sólo aplica a hitscan.
var _recoil_offset: float = 0.0
var _recoil_recovery_speed: float = 10.0  # se actualiza por arma al disparar

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

# === SIERRA (slot 8) ===
# Estado runtime del input-held de la sierra. _saw_audio es el handle
# devuelto por AudioManager.play_sfx_loop, _saw_sparks el GPUParticles3D
# persistente que se reposiciona al contact point cada frame.
var _saw_active: bool = false
var _saw_damage_timer: float = 0.0
var _saw_audio: AudioStreamPlayer = null
var _saw_sparks: GPUParticles3D = null

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
const SAW_SPARKS_SCENE: PackedScene = preload("res://scenes/effects/saw_sparks.tscn")

# Sierra (slot 8 / type "melee_held"): daño 2 cada 0.1s = 20 DPS, rango 2u.
const SAW_DAMAGE_INTERVAL: float = 0.1
const SAW_RANGE: float = 2.0
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
	# GPUParticles3D persistente para chispas de sierra. Hijo del player para
	# limpieza automática al reload de nivel; sin embargo seteamos
	# local_coords=false vía .tscn para que las partículas queden en world
	# space y no sigan al player cuando este se mueve.
	_saw_sparks = SAW_SPARKS_SCENE.instantiate()
	add_child(_saw_sparks)
	_saw_sparks.emitting = false

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
	var pistol: Weapon = Weapon.new("Pistola", 1, 0.2, 50.0)
	pistol.recoil_amount = deg_to_rad(0.5)
	pistol.recoil_recovery_time = 0.3
	var shotgun: Weapon = Weapon.new("Escopeta", 3, 0.8, 10.0, 0.12, 6)
	shotgun.recoil_amount = deg_to_rad(2.0)
	shotgun.recoil_recovery_time = 0.5
	var rifle: Weapon = Weapon.new("Rifle", 2, 0.4, 100.0)
	rifle.recoil_amount = deg_to_rad(1.0)
	rifle.recoil_recovery_time = 0.4
	weapons = [
		pistol,
		shotgun,
		rifle,
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
	# Slot 7: Hacha. Pesada (0.8s), daño 12, rango 2.5u. Mata casi todo de
	# un golpe pero el cooldown impide spamear.
	var axe: Weapon = Weapon.new("Hacha", 12, 0.8, 2.5, 0.0, 1, -1, "melee_swing")
	axe.sfx_name = "chop"
	axe.vfx_color = Color(1.0, 0.2, 0.2, 1)
	weapons.append(axe)
	# Slot 8: Sierra eléctrica. type "melee_held": DPS continuo mientras LMB
	# apretado. damage=2 cada 0.1s = 20 DPS, rango 2u. fire_rate=0 porque el
	# cooldown global no aplica (la lógica vive en _physics_process).
	var saw: Weapon = Weapon.new("Sierra", 2, 0.0, SAW_RANGE, 0.0, 1, -1, "melee_held")
	saw.sfx_name = "saw_motor"
	saw.vfx_color = Color(1.0, 0.85, 0.3, 1)
	weapons.append(saw)

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
		"melee_held":
			# El input held se maneja en _physics_process / _update_saw_input.
			# Este click discreto no hace nada; el `pass` evita el warning del
			# default case y mantiene shoot() consistente para todas las armas.
			pass
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

	# Recoil: aplica un pitch-up inmediato y registra el offset acumulado
	# para que _physics_process lo decaiga gradualmente hasta 0.
	if w.recoil_amount > 0.0:
		_recoil_offset += w.recoil_amount
		camera.rotation.x = clamp(camera.rotation.x - w.recoil_amount, -1.5, 1.5)
		# Speed que lleva el offset al ~5% en recoil_recovery_time segundos
		# (matemática: e^-3 ≈ 0.05, así que speed = 3 / time).
		_recoil_recovery_speed = 3.0 / max(0.05, w.recoil_recovery_time)

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

		# DOS raycasts independientes:
		# - body_query: solo bodies (CharacterBody3D del enemy / muros).
		# - head_query: solo areas, filtrado por grupo "head_hitbox".
		# El HeadHitbox vive DENTRO de la cápsula del enemy; con un solo
		# raycast a "bodies+areas" la cápsula gana siempre. Separando en
		# dos rays y comparando distancias detectamos headshot limpio
		# cuando head_dist <= body_dist sobre el mismo path.
		var body_query = PhysicsRayQueryParameters3D.create(origin, to_pos)
		body_query.exclude = [self.get_rid()]
		body_query.collide_with_bodies = true
		body_query.collide_with_areas = false
		var body_result: Dictionary = space_state.intersect_ray(body_query)

		var head_query = PhysicsRayQueryParameters3D.create(origin, to_pos)
		head_query.collide_with_bodies = false
		head_query.collide_with_areas = true
		var head_result: Dictionary = space_state.intersect_ray(head_query)

		# Lógica de headshot: el HeadHitbox está DENTRO de la cápsula del enemy,
		# así que con un ray horizontal el body ray entra ANTES que el head ray
		# (cápsula radius > sphere radius desde fuera). Por eso no comparamos
		# distancias: es headshot cuando el head_result y el body_result son del
		# MISMO enemy (el ray atraviesa el cuerpo Y la zona de la cabeza).
		var is_headshot: bool = false
		var hit_result: Dictionary = {}
		var damage_target: Node = null
		if body_result:
			damage_target = body_result.collider
			hit_result = body_result
			if head_result and head_result.collider.is_in_group("head_hitbox"):
				var head_owner: Node = head_result.collider.get_parent()
				if head_owner == damage_target:
					is_headshot = true
					hit_result = head_result  # blood en la cabeza, no en el torso
		elif head_result and head_result.collider.is_in_group("head_hitbox"):
			# El body ray no pegó pero el head ray sí (HeadHitbox sobresaliendo,
			# o ray que pasa por encima del cuerpo). También cuenta como headshot.
			is_headshot = true
			hit_result = head_result
			damage_target = head_result.collider.get_parent()

		if debug_shooting:
			print("[shoot] arma=", w.weapon_name, " pellet=", _i,
					" from=", origin, " to=", to_pos,
					" hit=", damage_target,
					" headshot=", is_headshot)

		if hit_result.is_empty():
			continue
		if damage_target and damage_target.has_method("take_damage"):
			var final_damage: int = w.damage * 2 if is_headshot else w.damage
			if debug_shooting:
				print("[shoot]   -> take_damage(", final_damage, ") en ", damage_target.name, " headshot=", is_headshot)
			damage_target.take_damage(final_damage)
			ParticleManager.spawn_blood(hit_result.position)
			if damage_target.is_in_group("enemy"):
				if is_headshot:
					AudioManager.play_sfx("headshot_ding")
				else:
					AudioManager.play_sfx("hitmarker_tick")
		else:
			ParticleManager.spawn_impact(hit_result.position, hit_result.normal, "wall")

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

func take_damage(amount: int, attacker_position: Vector3 = Vector3.INF):
	if is_dead:
		return
	AudioManager.play_sfx("hit", 0.0, 0.9)
	ParticleManager.show_damage_vignette()
	health -= amount
	print("¡DAÑO RECIBIDO! Vida: ", health, "/", max_health)
	update_hud()

	if hud:
		hud.show_message("¡DAÑO!", 0.3)

	# Damage indicator direccional. Si el caller pasó attacker_position,
	# convertimos al espacio LOCAL del player (eje X local = derecha,
	# +Z local = atrás porque -Z es "forward" en Godot) y discretizamos
	# al eje dominante.
	if attacker_position != Vector3.INF and hud and hud.has_method("show_damage_indicator"):
		var to_attacker: Vector3 = attacker_position - global_position
		to_attacker.y = 0
		if to_attacker.length_squared() > 0.001:
			var local_x: float = transform.basis.x.dot(to_attacker)
			var local_z: float = transform.basis.z.dot(to_attacker)
			if abs(local_z) > abs(local_x):
				if local_z > 0:
					hud.show_damage_indicator(hud.DamageDir.BOTTOM)
				else:
					hud.show_damage_indicator(hud.DamageDir.TOP)
			else:
				if local_x > 0:
					hud.show_damage_indicator(hud.DamageDir.RIGHT)
				else:
					hud.show_damage_indicator(hud.DamageDir.LEFT)

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

	# Alcance del raycast del aim: 2x max_range del arma activa (default
	# 100u). El raycast es SOLO para feedback visual del crosshair y la
	# barra de salud — el daño del disparo sigue limitado por w.max_range
	# en _fire_hitscan, no se afecta.
	var aim_ray_length: float = 100.0
	if not weapons.is_empty():
		var w_range: Weapon = weapons[current_weapon_index]
		if w_range.max_range > 0.0:
			aim_ray_length = w_range.max_range * 2.0
	raycast.target_position = Vector3(0, 0, -aim_ray_length)
	raycast.force_raycast_update()

	# Dos buckets de "enemy apuntado":
	# - aimed: con el filtro estricto de 40u, alimenta la barra de HP del
	#   EnemyHealthIndicator (preservamos comportamiento original).
	# - aimed_far: cualquier enemy en el raycast extendido, alimenta el
	#   color del crosshair (para que amarillo/rojo se vean al borde y
	#   fuera del max_range del arma).
	var aimed: Node = null
	var aimed_far: Node = null
	var aim_distance: float = 0.0
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("enemy"):
			aim_distance = camera.global_position.distance_to(raycast.get_collision_point())
			if aim_distance <= enemy_indicator_max_distance:
				aimed = collider
			aimed_far = collider
	hud.update_enemy_indicator(aimed)

	# Indicador de alcance del crosshair: verde si el enemy apuntado está
	# bien dentro del rango del arma, amarillo si está al borde, rojo si
	# está fuera. Blanco cuando no hay enemy o el arma es explosiva
	# (granada/bazuca tienen radio en vez de rango lineal; no aplica).
	if hud.has_method("set_crosshair_color"):
		var color: Color = Color(1, 1, 1, 1)  # default blanco
		if aimed_far != null and not weapons.is_empty():
			var w: Weapon = weapons[current_weapon_index]
			if w.type != "grenade" and w.type != "rocket" and w.max_range > 0.0:
				var ratio: float = aim_distance / w.max_range
				if ratio <= 0.8:
					color = Color(0.2, 1.0, 0.2, 1)  # verde
				elif ratio <= 1.0:
					color = Color(1.0, 1.0, 0.2, 1)  # amarillo
				else:
					color = Color(1.0, 0.3, 0.3, 1)  # rojo
		hud.set_crosshair_color(color)

	# Target indicator estilo Predator: visible mientras el raycast
	# detecta un enemy (cualquier distancia dentro del aim_ray_length).
	if hud.has_method("set_target_locked"):
		hud.set_target_locked(aimed_far != null)

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

	# Recoil decay: bajamos _recoil_offset hacia 0 con velocidad
	# _recoil_recovery_speed (seteada por el arma al disparar). El delta
	# del lerp se SUMA a camera.rotation.x para que la cámara baje
	# proporcionalmente a lo que cae el offset. Esto no pisa el mouse:
	# el mouse modifica rotation.x libremente, nosotros sólo ajustamos
	# por el delta del recoil que se "descarga".
	if _recoil_offset > 0.0001:
		var prev_offset: float = _recoil_offset
		_recoil_offset = lerp(_recoil_offset, 0.0, clamp(delta * _recoil_recovery_speed, 0.0, 1.0))
		camera.rotation.x = clamp(camera.rotation.x + (prev_offset - _recoil_offset), -1.5, 1.5)

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Tracker de edge: detectar transición up→down del SPACE para que el
	# segundo salto requiera soltar y re-apretar (no auto-rebota).
	var space_held: bool = Input.is_key_pressed(KEY_SPACE)
	var space_just_pressed: bool = space_held and not _space_held_prev
	_space_held_prev = space_held

	if space_held and is_on_floor():
		velocity.y = jump_velocity
	elif space_just_pressed and not is_on_floor() and not has_double_jumped:
		velocity.y = jump_velocity * DOUBLE_JUMP_VELOCITY_FACTOR
		has_double_jumped = true
		AudioManager.play_sfx("double_jump")
		ParticleManager.spawn_jump_puff(global_position)

	# Reset del flag al pisar suelo (acá, no en is_on_floor branch arriba,
	# para que sea claro que es post-physics).
	if is_on_floor():
		has_double_jumped = false
	
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
	_update_saw_input(delta)

# Sierra eléctrica (slot 8, type "melee_held"). Lógica de input held +
# tick de daño + reposicionamiento de chispas. Se llama cada frame desde
# _physics_process.
func _update_saw_input(delta: float) -> void:
	var w: Weapon = null
	if not weapons.is_empty():
		w = weapons[current_weapon_index]
	var is_saw: bool = w != null and w.type == "melee_held"
	var lmb_held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Detener si cambiaste de arma o soltaste LMB.
	if not is_saw or not lmb_held or is_dead:
		if _saw_active:
			_stop_saw()
		return
	if not _saw_active:
		_start_saw(w)

	# Raycast cada frame para responsividad de chispas (no esperan al tick
	# de daño). El daño en sí se aplica solo cuando el timer expira.
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * SAW_RANGE)
	query.exclude = [self.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	var hit_target: Node = null
	if result:
		hit_target = result.collider
		if _saw_sparks:
			_saw_sparks.global_position = result.position
			_saw_sparks.emitting = true
	else:
		if _saw_sparks:
			_saw_sparks.emitting = false

	# Tick de daño cada SAW_DAMAGE_INTERVAL segundos, sólo si hay hit válido.
	_saw_damage_timer -= delta
	if _saw_damage_timer <= 0.0:
		_saw_damage_timer = SAW_DAMAGE_INTERVAL
		if hit_target and hit_target.has_method("take_damage"):
			hit_target.take_damage(w.damage)

func _start_saw(w: Weapon) -> void:
	_saw_active = true
	_saw_damage_timer = 0.0  # tick inmediato al arrancar
	if w.sfx_name != "":
		_saw_audio = AudioManager.play_sfx_loop(w.sfx_name)

func _stop_saw() -> void:
	_saw_active = false
	if _saw_audio:
		AudioManager.stop_sfx_loop(_saw_audio)
		_saw_audio = null
	if _saw_sparks:
		_saw_sparks.emitting = false

func _exit_tree() -> void:
	# Si la escena cambia o el player es queue_free con la sierra activa,
	# parar el audio loop (AudioManager es autoload y el AudioStreamPlayer
	# vive ahí; sin esto el motor seguiría sonando tras el reload).
	if _saw_active:
		_stop_saw()
