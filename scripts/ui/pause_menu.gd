extends Control

# ============================================
# NEXUS - Menú de Pausa
# ============================================

const SETTINGS_MENU_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

@onready var buttons_box: VBoxContainer = $VBoxContainer

# Instancia del settings overlay mientras está abierto. null cuando no.
var _settings_overlay: Control = null

func _ready():
	visible = false
	# Este nodo debe seguir funcionando cuando el juego esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC
		# Si el overlay de settings está abierto, dejá que él maneje el ESC.
		if _settings_overlay != null:
			return
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
	# Abrir settings como overlay. NO se despausa, NO se cambia de escena,
	# así el nivel preserva su estado al volver.
	if _settings_overlay != null:
		return
	var overlay := SETTINGS_MENU_SCENE.instantiate() as Control
	overlay.open_as_overlay()
	overlay.closed.connect(_on_settings_overlay_closed)
	# Ocultar botones del pause mientras se ve el settings (queda el ColorRect de fondo).
	buttons_box.visible = false
	add_child(overlay)
	_settings_overlay = overlay

func _on_settings_overlay_closed() -> void:
	_settings_overlay = null
	buttons_box.visible = true

func _on_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
