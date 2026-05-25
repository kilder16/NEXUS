extends Control

# === SETTINGS MENU ===
# Script de la UI del menú de configuración gráfica.
# Se conecta a SettingsManager (autoload singleton).
#
# La escena .tscn debe tener esta estructura mínima (nombres exactos):
#   - SettingsMenu (Control, este script)
#       - MarginContainer
#           - VBoxContainer
#               - TitleLabel (Label, texto "Configuración" o "Settings")
#               - FullscreenCheck (CheckButton, texto "Pantalla completa")
#               - VsyncCheck (CheckButton, texto "VSync")
#               - QualityHBox (HBoxContainer)
#                   - QualityLabel (Label, texto "Calidad gráfica")
#                   - QualityOption (OptionButton)
#               - BackButton (Button, texto "Volver")
#
# Acepta una variable de retorno previa_scene_path: si se setea, BackButton
# vuelve a esa escena. Si no, vuelve al menú principal.

@onready var fullscreen_check: CheckButton = $MarginContainer/VBoxContainer/FullscreenCheck
@onready var vsync_check: CheckButton = $MarginContainer/VBoxContainer/VsyncCheck
@onready var quality_option: OptionButton = $MarginContainer/VBoxContainer/QualityHBox/QualityOption
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

# Modo overlay: cuando es true, el menú se cierra emitiendo `closed` y haciendo
# queue_free, sin tocar la escena actual. Se usa desde pause_menu para que no
# se reinicie el nivel. Llamar open_as_overlay() antes de add_child() para
# que tome efecto desde _ready.
signal closed
var overlay_mode: bool = false

# Path de la escena anterior; el menú principal lo setea al instanciar este menú
var previous_scene_path: String = "res://scenes/ui/main_menu.tscn"

func open_as_overlay() -> void:
	overlay_mode = true
	# Procesa input aunque el juego esté pausado (pause_menu mantiene tree.paused = true).
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	# Consumir return path si alguien (pause_menu) lo seteó antes del swap.
	# Se limpia para no contaminar futuras aperturas desde el main menu.
	if SettingsManager.pending_return_path != "":
		previous_scene_path = SettingsManager.pending_return_path
		SettingsManager.pending_return_path = ""

	# Llenar OptionButton de calidad
	quality_option.clear()
	for name in SettingsManager.QUALITY_NAMES:
		quality_option.add_item(name)
	
	# Sincronizar UI con estado actual de SettingsManager
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	vsync_check.button_pressed = SettingsManager.vsync
	quality_option.select(SettingsManager.quality)
	
	# Conectar señales
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	quality_option.item_selected.connect(_on_quality_selected)
	back_button.pressed.connect(_on_back_pressed)

func _on_fullscreen_toggled(value: bool):
	SettingsManager.set_fullscreen(value)

func _on_vsync_toggled(value: bool):
	SettingsManager.set_vsync(value)

func _on_quality_selected(index: int):
	SettingsManager.set_quality(index)

func _on_back_pressed():
	if overlay_mode:
		closed.emit()
		queue_free()
	else:
		get_tree().change_scene_to_file(previous_scene_path)

func _unhandled_input(event):
	# ESC también vuelve atrás
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
