extends CanvasLayer

# ============================================
# NEXUS - HUD (Interfaz en pantalla)
# ============================================

@onready var health_label = $HealthLabel
@onready var block_label = $BlockLabel
@onready var weapon_label = $WeaponLabel
@onready var crosshair = $Crosshair
@onready var message_label = $MessageLabel

var block_names = ["Muro", "Rampa", "Plataforma"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ocultar mensaje inicial
	if message_label:
		message_label.visible = false

func _process(_delta: float) -> void:
	# Ocultar crosshair cuando el mouse no está capturado (pause, winscreen,
	# gameover, settings). Una sola regla universal evita tocar cada caller
	# de Input.set_mouse_mode.
	if crosshair:
		crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func update_health(current_health: int, max_health: int):
	if health_label:
		health_label.text = "Vida: %d/%d" % [current_health, max_health]
		# Cambiar color según vida
		if current_health <= 3:
			health_label.add_theme_color_override("font_color", Color.RED)
		elif current_health <= 6:
			health_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			health_label.add_theme_color_override("font_color", Color.GREEN)

func update_block_type(block_type: int):
	if block_label:
		block_label.text = "Bloque: %s [Q/E]" % block_names[block_type]

func update_weapon(weapon_name: String):
	if weapon_label:
		weapon_label.text = "Arma: %s [1/2/3]" % weapon_name

func show_message(text: String, duration: float = 2.0):
	if message_label:
		message_label.text = text
		message_label.visible = true
		await get_tree().create_timer(duration).timeout
		message_label.visible = false
