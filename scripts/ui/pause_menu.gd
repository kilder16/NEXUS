extends Control

# ============================================
# NEXUS - Menú de Pausa
# ============================================

func _ready():
	visible = false
	# Este nodo debe seguir funcionando cuando el juego esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC
		toggle_pause()

func toggle_pause():
	visible = !visible
	get_tree().paused = visible
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_button_pressed():
	toggle_pause()

func _on_settings_button_pressed():
	# Setear retorno al nivel actual antes del swap. settings_menu lo consume en _ready.
	SettingsManager.pending_return_path = get_tree().current_scene.scene_file_path
	# Despausar y liberar mouse (settings_menu necesita mouse visible).
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func _on_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
