extends Node3D

# === NEXUS - Controlador del Sector 01 ===
# Tracking de stats + transición al WinScreen al alcanzar el objective.
# No tiene gate de boss (a diferencia de level_05); el objective está
# activo desde el inicio y la guide light verde es visible siempre.

const LEVEL_TITLE: String = "INFILTRACIÓN EXITOSA"
const LEVEL_NARRATIVE: String = "Sector 01 asegurado.
Avanzando hacia el siguiente módulo."
const OBJECTIVE_HINT: String = "Misión: alcanzar la zona de extracción"

# Balance pass v1.1 (task #5 Día 5): la combinación Asaltante (melee rápido)
# + Centinela (ranged 1.5s) hacía pinza demasiado opresiva en el nivel
# introductorio. Override sólo en level_01: Centinelas pasan a 2.5s entre
# disparos. Otros niveles mantienen el cooldown default de 1.5s.
const SENTINEL_COOLDOWN_OVERRIDE: float = 2.5
const ENEMY_BASE_SCRIPT: Script = preload("res://scripts/ai/enemy.gd")

@onready var objective: Area3D = $Objective
@onready var win_screen: Control = $WinScreen
@onready var hud: CanvasLayer = $HUD

var start_time: float = 0.0
var enemies_killed: int = 0
var total_enemies: int = 0

func _ready() -> void:
	objective.use_default_victory = false
	objective.body_entered.connect(_on_objective_reached)

	# Iterar enemigos del nivel para contar y trackear muertes + balance pass.
	# Los enemies hacen su propio _ready antes que éste (orden bottom-up de
	# Godot), así que get_script() y attack_cooldown ya están seteados con
	# sus defaults cuando los leemos acá.
	var sentinel_override_count: int = 0
	for child in get_children():
		if child.has_signal("died"):
			child.died.connect(_on_enemy_died)
			total_enemies += 1
		# Override del cooldown sólo en Centinelas (script base enemy.gd
		# puro; subclases enemy_fast/tank/ranged tienen sus propios scripts
		# y no matchean).
		if child.get_script() == ENEMY_BASE_SCRIPT:
			child.attack_cooldown = SENTINEL_COOLDOWN_OVERRIDE
			sentinel_override_count += 1
	if sentinel_override_count > 0:
		print("[Level01] Cooldown Centinela override: ", sentinel_override_count, " enemigos a ", SENTINEL_COOLDOWN_OVERRIDE, "s")

	start_time = Time.get_ticks_msec() / 1000.0

	# Mensaje contextual al inicio (esperar 1 frame para que HUD se inicialice)
	await get_tree().process_frame
	if hud and hud.has_method("show_message"):
		hud.show_message(OBJECTIVE_HINT, 3.5)

func _on_enemy_died(_e: Node) -> void:
	enemies_killed += 1

func _on_objective_reached(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - start_time
	if hud and hud.has_method("show_message"):
		hud.show_message("Objetivo asegurado", 2.0)
	win_screen.show_final_victory(elapsed, enemies_killed, total_enemies, LEVEL_TITLE, LEVEL_NARRATIVE)
