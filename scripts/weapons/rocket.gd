extends Area3D

# Cohete de bazuca: movimiento lineal constante, sin físicas. Al impactar
# contra cualquier body (excepto el shooter) explota en radio con dropoff.

const SPEED: float = 20.0
const LIFETIME: float = 4.0
const EXPLOSION_RADIUS: float = 4.0
const EXPLOSION_DAMAGE: int = 15

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/effects/explosion.tscn")

var direction: Vector3 = Vector3.FORWARD
var shooter: Node = null

var _exploded: bool = false
var _oriented: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Auto-destruir si no impactó nada en LIFETIME segundos.
	await get_tree().create_timer(LIFETIME).timeout
	if is_instance_valid(self) and not _exploded:
		queue_free()

func _physics_process(delta: float) -> void:
	# El shooter setea direction tras add_child (post _ready). Alineamos
	# la cápsula al vector de vuelo en la primera frame.
	if not _oriented and direction.length_squared() > 0.001:
		var up: Vector3 = Vector3.UP
		if abs(direction.normalized().dot(Vector3.UP)) > 0.99:
			up = Vector3.RIGHT
		look_at(global_position + direction, up)
		# CapsuleMesh tiene eje largo en Y; look_at lo deja en -Z. Rotamos
		# 90° en X para alinear la cápsula al sentido de vuelo.
		rotate_object_local(Vector3.RIGHT, PI / 2.0)
		_oriented = true
	global_position += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body == shooter or body == self:
		return
	_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	var scene: Node = get_tree().current_scene
	if scene != null:
		var fx: Node3D = EXPLOSION_SCENE.instantiate()
		scene.add_child(fx)
		fx.global_position = global_position

	AudioManager.play_sfx("explosion")

	# Daño en radio sólo a enemigos. Falloff lineal: 100% al centro, 0% al borde.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("take_damage"):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist > EXPLOSION_RADIUS:
			continue
		var falloff: float = clamp(1.0 - (dist / EXPLOSION_RADIUS), 0.0, 1.0)
		var dmg: int = int(round(EXPLOSION_DAMAGE * falloff))
		if dmg > 0:
			enemy.take_damage(dmg)

	queue_free()
