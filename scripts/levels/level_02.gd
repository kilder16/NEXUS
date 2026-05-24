extends Node3D

# === NEXUS - Controlador del Sector 02 ===
# Mismo patrón que level_01: tracking + WinScreen al objective.
# Sin gate de boss, guide light visible desde el inicio.

const LEVEL_TITLE: String = "SECTOR ASEGURADO"
const LEVEL_NARRATIVE: String = "Complejo industrial neutralizado.
Nexus retrocede."
const OBJECTIVE_HINT: String = "Misión: cruzar el complejo y extraer"

@onready var objective: Area3D = $Objective
@onready var win_screen: Control = $WinScreen
@onready var hud: CanvasLayer = $HUD

var start_time: float = 0.0
var enemies_killed: int = 0
var total_enemies: int = 0

func _ready() -> void:
	objective.use_default_victory = false
	objective.body_entered.connect(_on_objective_reached)

	for child in get_children():
		if child.has_signal("died"):
			child.died.connect(_on_enemy_died)
			total_enemies += 1

	start_time = Time.get_ticks_msec() / 1000.0

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
