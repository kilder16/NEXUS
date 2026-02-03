extends Area3D

# Objetivo del nivel - el jugador debe llegar aquí para ganar

var rotation_speed = 1.0

func _ready():
	# Conectar la señal cuando un cuerpo entra
	body_entered.connect(_on_body_entered)
	print("Objetivo del nivel activado")

func _process(delta):
	# Rotar para que se vea llamativo
	rotate_y(rotation_speed * delta)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("=== ¡NIVEL COMPLETADO! ===")
		# Mostrar mensaje de victoria
		var label = Label.new()
		label.text = "¡NIVEL COMPLETADO!"
		label.add_theme_font_size_override("font_size", 48)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.anchors_preset = Control.PRESET_CENTER
		
		var canvas = CanvasLayer.new()
		canvas.add_child(label)
		get_tree().current_scene.add_child(canvas)
		
		# Liberar mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Reiniciar después de 3 segundos
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()
