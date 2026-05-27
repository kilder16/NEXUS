extends Node3D

# === NEXUS - Controlador del nivel final (El Núcleo) ===

const BOSS_DEATH_DELAY: float = 1.5  # pausa cinematográfica tras matar al boss

# Override del detect_range de los Tiradores en este nivel: con el spawn del
# player a (0,1,14) y los Tiradores a (±10, 3.5, 0), la distancia 3D es
# ≈17.39u — por encima del default 15u de enemy_ranged.gd, así que se
# quedaban en PATROL hasta que el player se acercara. 22u cubre el caso
# desde el spawn sin volverlos omniscientes en todo el nivel.
const TIRADOR_DETECT_OVERRIDE: float = 22.0
const ENEMY_RANGED_SCRIPT: Script = preload("res://scripts/ai/enemy_ranged.gd")

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
	# y overridear detect_range de los Tiradores (spawn lejano, ver const).
	var tirador_override_count: int = 0
	for child in get_children():
		if child.has_signal("died"):
			child.died.connect(_on_enemy_died)
			total_enemies += 1
		if child.get_script() == ENEMY_RANGED_SCRIPT:
			child.detect_range = TIRADOR_DETECT_OVERRIDE
			tirador_override_count += 1
	if tirador_override_count > 0:
		print("[Level05] detect_range Tirador override: ", tirador_override_count, " enemigos a ", TIRADOR_DETECT_OVERRIDE, "u")

	# Conexión adicional para el boss específicamente (activa la extracción)
	boss.died.connect(_on_boss_died)

	start_time = Time.get_ticks_msec() / 1000.0
	# Los stats del boss (HP 50, escudo 15, display_name) ahora viven en
	# scripts/ai/boss_final.gd::_ready. Mejor encapsulación: el boss conoce
	# sus propios stats y este level no necesita esperar process_frame
	# para overridearlos manualmente.

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
