extends Area3D

# === PROYECTIL CORTO ===
# Usado por Centinela (enemy.gd base). Más corto, más lento y menos
# alcance temporal que el proyectil del Tirador (enemy_ranged).

var speed = 10.0
var damage = 1
var lifetime = 2.0
var direction = Vector3.FORWARD
var shooter: Node = null
var _oriented: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta):
	# El shooter setea direction después de add_child (post _ready). Orientamos
	# la cápsula en la primera frame para que su eje largo apunte al vuelo.
	if not _oriented and direction.length_squared() > 0.001:
		var up: Vector3 = Vector3.UP
		if abs(direction.normalized().dot(Vector3.UP)) > 0.99:
			up = Vector3.RIGHT
		look_at(global_position + direction, up)
		rotate_object_local(Vector3.RIGHT, PI / 2.0)
		_oriented = true
	global_position += direction * speed * delta

func _on_body_entered(body):
	if body == shooter:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		# Pasar la posición del shooter para el damage indicator (Feature 4.3).
		var origin: Vector3 = shooter.global_position if shooter else global_position
		body.take_damage(damage, origin)
	queue_free()
