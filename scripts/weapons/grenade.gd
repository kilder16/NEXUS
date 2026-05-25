extends RigidBody3D

# Granada física: fuse de 2s, al explotar instancia VFX, reproduce SFX y
# aplica daño en radio con dropoff lineal. No daña al player (no friendly fire).

const FUSE_TIME: float = 2.0
const EXPLOSION_RADIUS: float = 5.0
const EXPLOSION_DAMAGE: int = 10

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/effects/explosion.tscn")

var _exploded: bool = false

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = FUSE_TIME
	timer.one_shot = true
	timer.timeout.connect(_explode)
	add_child(timer)
	timer.start()

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

	# Daño en radio sólo a enemigos. Falloff lineal: 100% al centro, 0% en el borde.
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
