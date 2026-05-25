extends Area3D

# === PROYECTIL ===
# Usado por EnemyRanged. Vuela en línea recta y daña al jugador.

var speed = 15.0
var damage = 1
var lifetime = 3.0
var direction = Vector3.FORWARD
var shooter: Node = null

func _ready():
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	if body == shooter:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		# Pasar la posición del shooter para que el HUD del player muestre
		# el damage indicator direccional (Feature 4.3).
		var origin: Vector3 = shooter.global_position if shooter else global_position
		body.take_damage(damage, origin)
	queue_free()
