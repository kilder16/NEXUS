extends Node

# === NEXUS - Particle Manager (autoload singleton) ===
# Spawn de partículas 3D y vignette UI. Las escenas se auto-destruyen.

const MUZZLE_FLASH := preload("res://scenes/effects/muzzle_flash.tscn")
const IMPACT_WALL := preload("res://scenes/effects/impact_wall.tscn")
const BLOOD_SPLATTER := preload("res://scenes/effects/blood_splatter.tscn")
const ENEMY_DEATH_FX := preload("res://scenes/effects/enemy_death_fx.tscn")

const VIGNETTE_PEAK: float = 0.7
const VIGNETTE_DURATION: float = 0.3

# ============================================================
# API pública
# ============================================================

func spawn_muzzle_flash(pos: Vector3, dir: Vector3) -> void:
	var inst: Node3D = MUZZLE_FLASH.instantiate()
	_add_to_world(inst)
	inst.global_position = pos
	_orient_along(inst, pos, dir)

func spawn_impact(pos: Vector3, normal: Vector3, type: String = "wall") -> void:
	if type != "wall":
		push_warning("[ParticleManager] impact type '%s' no implementado, usando 'wall'" % type)
	var inst: Node3D = IMPACT_WALL.instantiate()
	_add_to_world(inst)
	inst.global_position = pos
	_orient_along(inst, pos, normal)

func spawn_blood(pos: Vector3) -> void:
	var inst: Node3D = BLOOD_SPLATTER.instantiate()
	_add_to_world(inst)
	inst.global_position = pos

func spawn_enemy_death(pos: Vector3) -> void:
	var inst: Node3D = ENEMY_DEATH_FX.instantiate()
	_add_to_world(inst)
	inst.global_position = pos

func show_damage_vignette() -> void:
	var vignette: Node = get_tree().get_first_node_in_group("damage_vignette")
	if vignette == null:
		return
	var mat: ShaderMaterial = vignette.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("intensity", VIGNETTE_PEAK)
	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/intensity", 0.0, VIGNETTE_DURATION)

# ============================================================
# Internos
# ============================================================

func _add_to_world(inst: Node3D) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		push_warning("[ParticleManager] No current_scene; descartando partícula")
		inst.queue_free()
		return
	scene.add_child(inst)

func _orient_along(inst: Node3D, pos: Vector3, dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	# look_at orienta el local -Z hacia (pos + dir). Si dir es paralelo a UP,
	# usamos RIGHT como up vector para evitar el gimbal lock.
	var up: Vector3 = Vector3.UP
	if abs(dir.normalized().dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT
	inst.look_at(pos + dir, up)
