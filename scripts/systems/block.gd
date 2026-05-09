extends StaticBody3D

# Tipo de bloque (0=Muro, 1=Rampa, 2=Plataforma)
var block_type: int = 0

# Colores para cada tipo de bloque
var block_colors = [
	Color(0.3, 0.3, 0.8),  # Muro - Azul
	Color(0.8, 0.5, 0.2),  # Rampa - Naranja
	Color(0.2, 0.8, 0.3)   # Plataforma - Verde
]

func _ready():
	# Aplicar color según el tipo
	apply_color()

func apply_color():
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = block_colors[block_type]
		mesh_instance.material_override = material

func take_damage(_amount: int = 1):
	print("¡BLOQUE DESTRUIDO!")
	# Efecto visual antes de destruir (opcional)
	queue_free()
