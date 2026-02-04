extends Control

# ============================================
# NEXUS - Menú Principal
# ============================================

func _ready():
	# Asegurar que el mouse sea visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Asegurar que el juego no esté pausado
	get_tree().paused = false

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/test_level.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
