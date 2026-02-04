extends Control

# ============================================
# NEXUS - Pantalla Game Over / Victoria
# ============================================

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var message_label = $Panel/VBoxContainer/MessageLabel

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_game_over():
	if title_label:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color.RED)
	if message_label:
		message_label.text = "Has sido eliminado"
	_show()

func show_victory():
	if title_label:
		title_label.text = "¡NIVEL COMPLETADO!"
		title_label.add_theme_color_override("font_color", Color.GREEN)
	if message_label:
		message_label.text = "¡Objetivo alcanzado!"
	_show()

func _show():
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_retry_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
