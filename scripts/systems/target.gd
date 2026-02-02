extends StaticBody3D

func take_damage():
	print("¡TARGET DESTRUIDO!")
	queue_free()  # Elimina el objeto del juego
