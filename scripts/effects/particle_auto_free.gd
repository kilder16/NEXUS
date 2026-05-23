extends Node3D

# Auto-destruye el nodo (y sus particles hijos) tras lifetime_seconds.
# Usado por todas las escenas de efectos en res://scenes/effects/.
# Como extiende Node3D, se puede attachear a Node3D, GPUParticles3D, etc.

@export var lifetime_seconds: float = 0.5

func _ready() -> void:
	await get_tree().create_timer(lifetime_seconds).timeout
	queue_free()
