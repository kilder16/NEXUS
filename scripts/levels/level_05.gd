extends Node3D

# === NEXUS - Controlador del nivel final (El Núcleo) ===

const BOSS_DEATH_DELAY: float = 1.5  # pausa cinematográfica tras matar al boss

@onready var boss: Node = $BossFinal
@onready var objective: Area3D = $Objective
@onready var guide_light: OmniLight3D = $ObjectiveGuideLight
@onready var win_screen: Control = $WinScreen
@onready var hud: CanvasLayer = $HUD

var start_time: float = 0.0
var enemies_killed: int = 0
var total_enemies: int = 0

func _ready() -> void:
	# Modo estricto: zona de extracción inactiva hasta matar al boss
	objective.monitoring = false
	objective.use_default_victory = false
	objective.body_entered.connect(_on_objective_reached)

	# Conectar señal died a todos los enemigos del nivel (iteración dinámica)
	for child in get_children():
		if child.has_signal("died"):
			child.died.connect(_on_enemy_died)
			total_enemies += 1

	# Conexión adicional para el boss específicamente (activa la extracción)
	boss.died.connect(_on_boss_died)

	start_time = Time.get_ticks_msec() / 1000.0

	# Override boss HP tras el _ready de enemy_tank (default = 8 post-balance)
	await get_tree().process_frame
	boss.health = 50
	print("[Level05] Boss HP override: ", boss.health)

func _on_enemy_died(_e: Node) -> void:
	enemies_killed += 1

func _on_boss_died(_e: Node) -> void:
	print("¡BOSS ELIMINADO! Activando extracción en %.1fs..." % BOSS_DEATH_DELAY)
	# Pausa cinematográfica: el jugador respira, ve caer al boss
	await get_tree().create_timer(BOSS_DEATH_DELAY).timeout
	objective.monitoring = true
	guide_light.visible = true
	if hud and hud.has_method("show_message"):
		hud.show_message("Acceso a zona de extracción habilitado", 3.0)

func _on_objective_reached(body: Node) -> void:
	if body.is_in_group("player"):
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - start_time
		win_screen.show_final_victory(elapsed, enemies_killed, total_enemies)
