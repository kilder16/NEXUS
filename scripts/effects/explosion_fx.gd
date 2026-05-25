extends Node3D

# Auto-destruye el efecto y maneja los tweens del flash (OmniLight) y la
# onda expansiva (SphereMesh). Las partículas son one_shot y se apagan solas.

@export var lifetime_seconds: float = 1.0
@export var flash_peak_energy: float = 8.0
@export var shockwave_max_scale: float = 5.0

@onready var _flash: OmniLight3D = get_node_or_null("Flash")
@onready var _shock: MeshInstance3D = get_node_or_null("Shockwave")

func _ready() -> void:
	if _flash:
		_flash.light_energy = flash_peak_energy
		var t_flash := create_tween()
		t_flash.tween_property(_flash, "light_energy", 0.0, lifetime_seconds * 0.6)
	if _shock:
		_shock.scale = Vector3.ONE * 0.3
		# Duplicar el material para que explosiones simultáneas no compartan
		# fade (el SubResource del .tscn es compartido entre instancias).
		var src_mat: Material = _shock.get_active_material(0)
		var mat: StandardMaterial3D = null
		if src_mat is StandardMaterial3D:
			mat = src_mat.duplicate() as StandardMaterial3D
			_shock.set_surface_override_material(0, mat)
		var t_shock := create_tween()
		t_shock.set_parallel(true)
		t_shock.tween_property(_shock, "scale", Vector3.ONE * shockwave_max_scale, lifetime_seconds * 0.8)
		if mat:
			var start_alpha: float = mat.albedo_color.a
			t_shock.tween_method(
				func(a: float) -> void:
					mat.albedo_color.a = a,
				start_alpha, 0.0, lifetime_seconds * 0.8
			)
	await get_tree().create_timer(lifetime_seconds).timeout
	queue_free()
