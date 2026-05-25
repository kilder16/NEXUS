extends Node3D

# VFX de slash horizontal usado por las armas melee (cuchillo, hacha, sierra).
# play(color) debe llamarse después de add_child para que _ready haya cacheado
# el mesh. Duplica el material para no compartir el fade entre slashes
# simultáneos.

const LIFETIME: float = 0.18
const START_SCALE: Vector3 = Vector3(0.4, 1.0, 1.0)
const END_SCALE: Vector3 = Vector3(1.8, 1.0, 1.0)
const SWING_DEGREES: float = 35.0

@onready var _mesh: MeshInstance3D = $Slash

var _mat: StandardMaterial3D = null

func _ready() -> void:
	if _mesh:
		var src: Material = _mesh.get_active_material(0)
		if src is StandardMaterial3D:
			_mat = src.duplicate() as StandardMaterial3D
			_mesh.set_surface_override_material(0, _mat)

func play(color: Color) -> void:
	if _mat:
		# Albedo y emissive al color pedido. Alpha inicial del albedo se respeta
		# (suele ser 0.9 del .tscn) para el fade out.
		_mat.albedo_color = Color(color.r, color.g, color.b, _mat.albedo_color.a)
		_mat.emission = color
	if _mesh:
		_mesh.scale = START_SCALE
		_mesh.rotation_degrees = Vector3(0, 0, -SWING_DEGREES * 0.5)
		var t: Tween = create_tween()
		t.set_parallel(true)
		t.tween_property(_mesh, "scale", END_SCALE, LIFETIME)
		t.tween_property(_mesh, "rotation_degrees:z", SWING_DEGREES * 0.5, LIFETIME)
		if _mat:
			var start_a: float = _mat.albedo_color.a
			t.tween_method(
				func(a: float) -> void:
					_mat.albedo_color.a = a,
				start_a, 0.0, LIFETIME
			)
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()
