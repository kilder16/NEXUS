extends CanvasLayer

# ============================================
# NEXUS - HUD (Interfaz en pantalla)
# ============================================

@onready var health_label = $HealthLabel
@onready var block_label = $BlockLabel
@onready var weapon_name_label: Label = $WeaponBox/WeaponNameLabel
@onready var weapon_slots_hbox: HBoxContainer = $WeaponBox/WeaponSlotsHBox
@onready var crosshair = $Crosshair
@onready var message_label = $MessageLabel

# Cantidad fija de slots de arma en el HUD (1..8). Coordinar con player.gd.
const WEAPON_SLOT_COUNT: int = 8

# Refs cacheadas a los PanelContainer de cada slot y sus styles.
var _slot_panels: Array = []
var _style_active: StyleBoxFlat
var _style_available: StyleBoxFlat
var _style_empty: StyleBoxFlat

# Indicador de salud de enemigos (aparece cuando el player apunta a uno)
@onready var enemy_indicator: Control = $EnemyHealthIndicator
@onready var enemy_name_label: Label = $EnemyHealthIndicator/VBox/NameLabel
@onready var enemy_shield_box: Panel = $EnemyHealthIndicator/VBox/ShieldBarBox
@onready var enemy_shield_fill: ColorRect = $EnemyHealthIndicator/VBox/ShieldBarBox/ShieldBarFill
@onready var enemy_bar_fill: ColorRect = $EnemyHealthIndicator/VBox/BarBox/BarFill
@onready var enemy_hp_label: Label = $EnemyHealthIndicator/VBox/HPLabel

var enemy_indicator_target_alpha: float = 0.0
const ENEMY_INDICATOR_FADE_RATE: float = 12.0  # ~0.25s para llegar al target

var block_names = ["Muro", "Rampa", "Plataforma"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ocultar mensaje inicial
	if message_label:
		message_label.visible = false
	_setup_weapon_slot_styles()
	_cache_weapon_slots()

func _setup_weapon_slot_styles() -> void:
	# Activo: bg cyan brillante, borde fino. Indica el arma seleccionada.
	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = Color(0, 0.7, 0.95, 0.95)
	_style_active.border_color = Color(0.5, 1, 1, 1)
	_style_active.border_width_left = 1
	_style_active.border_width_top = 1
	_style_active.border_width_right = 1
	_style_active.border_width_bottom = 1
	_style_active.corner_radius_top_left = 3
	_style_active.corner_radius_top_right = 3
	_style_active.corner_radius_bottom_left = 3
	_style_active.corner_radius_bottom_right = 3
	# Disponible: arma equipada pero no activa.
	_style_available = StyleBoxFlat.new()
	_style_available.bg_color = Color(0, 0, 0, 0.55)
	_style_available.border_color = Color(0.6, 0.6, 0.6, 1)
	_style_available.border_width_left = 1
	_style_available.border_width_top = 1
	_style_available.border_width_right = 1
	_style_available.border_width_bottom = 1
	_style_available.corner_radius_top_left = 3
	_style_available.corner_radius_top_right = 3
	_style_available.corner_radius_bottom_left = 3
	_style_available.corner_radius_bottom_right = 3
	# Vacío: slot reservado a un arma futura, sin instancia activa.
	_style_empty = StyleBoxFlat.new()
	_style_empty.bg_color = Color(0, 0, 0, 0.3)
	_style_empty.border_color = Color(0.25, 0.25, 0.25, 1)
	_style_empty.border_width_left = 1
	_style_empty.border_width_top = 1
	_style_empty.border_width_right = 1
	_style_empty.border_width_bottom = 1
	_style_empty.corner_radius_top_left = 3
	_style_empty.corner_radius_top_right = 3
	_style_empty.corner_radius_bottom_left = 3
	_style_empty.corner_radius_bottom_right = 3

func _cache_weapon_slots() -> void:
	_slot_panels.clear()
	if weapon_slots_hbox == null:
		return
	for i in range(WEAPON_SLOT_COUNT):
		var slot: PanelContainer = weapon_slots_hbox.get_node_or_null("Slot%d" % (i + 1))
		_slot_panels.append(slot)

func _process(delta: float) -> void:
	# Ocultar crosshair cuando el mouse no está capturado (pause, winscreen,
	# gameover, settings). Una sola regla universal evita tocar cada caller
	# de Input.set_mouse_mode.
	if crosshair:
		crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# Fade del indicador de enemigo hacia su alpha objetivo (suaviza on/off
	# del raycast cuando el aim pasa por el borde del enemigo).
	if enemy_indicator:
		enemy_indicator.modulate.a = lerp(
			enemy_indicator.modulate.a,
			enemy_indicator_target_alpha,
			clamp(delta * ENEMY_INDICATOR_FADE_RATE, 0.0, 1.0)
		)

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

func update_weapon(weapon_name: String, current_index: int = 0, total_weapons: int = 1) -> void:
	if weapon_name_label:
		weapon_name_label.text = "Arma: %s" % weapon_name
	for i in range(_slot_panels.size()):
		var panel: PanelContainer = _slot_panels[i]
		if panel == null:
			continue
		var style: StyleBoxFlat
		if i == current_index:
			style = _style_active
		elif i < total_weapons:
			style = _style_available
		else:
			style = _style_empty
		panel.add_theme_stylebox_override("panel", style)
		# Color del número: blanco en activo, amarillo en disponible, gris en vacío.
		var lbl: Label = panel.get_node_or_null("Label")
		if lbl:
			if i == current_index:
				lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			elif i < total_weapons:
				lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
			else:
				lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))

func show_message(text: String, duration: float = 2.0):
	if message_label:
		message_label.text = text
		message_label.visible = true
		await get_tree().create_timer(duration).timeout
		message_label.visible = false

func update_enemy_indicator(enemy) -> void:
	# Llamado por player.gd cada frame con el enemigo apuntado o null.
	if not enemy_indicator:
		return
	if enemy == null:
		enemy_indicator_target_alpha = 0.0
		return
	enemy_indicator_target_alpha = 1.0
	# Texto: si tiene escudo activo, se muestra "S:X/Y  H:A/B" para tener
	# referencia numérica además de las barras. Sin escudo, sólo HP.
	var has_shield: bool = enemy.max_shield > 0 and enemy.shield > 0
	if enemy_name_label:
		enemy_name_label.text = enemy.display_name
	if enemy_hp_label:
		if has_shield:
			enemy_hp_label.text = "Escudo %d/%d  ·  Vida %d/%d" % [enemy.shield, enemy.max_shield, enemy.health, enemy.max_health]
		else:
			enemy_hp_label.text = "%d / %d" % [enemy.health, enemy.max_health]
	# Barra de escudo (cyan): visible sólo mientras shield > 0.
	if enemy_shield_box:
		enemy_shield_box.visible = has_shield
	if enemy_shield_fill and has_shield:
		var s_ratio: float = float(enemy.shield) / float(max(1, enemy.max_shield))
		enemy_shield_fill.anchor_right = clamp(s_ratio, 0.0, 1.0)
	# Barra de HP (verde/amarillo/rojo según ratio).
	var ratio: float = float(enemy.health) / float(max(1, enemy.max_health))
	if enemy_bar_fill:
		enemy_bar_fill.anchor_right = clamp(ratio, 0.0, 1.0)
		if ratio > 0.6:
			enemy_bar_fill.color = Color(0.2, 1.0, 0.3, 1.0)   # verde
		elif ratio > 0.3:
			enemy_bar_fill.color = Color(1.0, 0.85, 0.15, 1.0) # amarillo
		else:
			enemy_bar_fill.color = Color(1.0, 0.2, 0.2, 1.0)   # rojo
