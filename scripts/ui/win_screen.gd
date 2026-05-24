extends Control

# === NEXUS - Pantalla de victoria final (level_05) ===

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var narrative_label: Label = $Panel/VBoxContainer/NarrativeLabel
@onready var time_label: Label = $Panel/VBoxContainer/StatsContainer/TimeLabel
@onready var kills_label: Label = $Panel/VBoxContainer/StatsContainer/KillsLabel

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_final_victory(seconds: float, kills: int, total: int, title: String = "", narrative: String = "") -> void:
	# Override de strings por-nivel; "" mantiene el texto default del .tscn (L05).
	if title != "" and title_label:
		title_label.text = title
	if narrative != "" and narrative_label:
		narrative_label.text = narrative

	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	if time_label:
		time_label.text = "Tiempo: %02d:%02d" % [mins, secs]
	if kills_label:
		kills_label.text = "Enemigos: %d / %d" % [kills, total]

	AudioManager.stop_music(2.0)
	AudioManager.play_sfx("victory")

	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	# Fade-in suave (sigue corriendo aunque el árbol esté pausado)
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
