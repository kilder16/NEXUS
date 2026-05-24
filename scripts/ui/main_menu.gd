extends Control

# === NEXUS - Menú Principal ===

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var level_select_button: Button = $VBoxContainer/LevelSelectButton
@onready var configuracion_button: Button = $VBoxContainer/ConfiguracionButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var version_label: Label = $VersionLabel
@onready var level_select_panel: Control = $LevelSelectPanel
@onready var background_fx: Node2D = $BackgroundFX
@onready var bg_particles: CPUParticles2D = $BackgroundFX/Particles

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	# Limpiar cualquier return path stale (ej. pause anterior que nunca abrió settings)
	SettingsManager.pending_return_path = ""
	AudioManager.play_music("menu_music", 2.0)

	# Background FX posicionado al bottom-center del viewport
	var vp_size: Vector2i = get_viewport().size
	background_fx.position = Vector2(vp_size.x / 2.0, vp_size.y + 20.0)
	bg_particles.emission_rect_extents = Vector2(vp_size.x / 2.0, 8.0)

	level_select_panel.back_pressed.connect(_on_panel_back)

	# Estado inicial oculto (antes del primer render)
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	play_button.modulate.a = 0.0
	level_select_button.modulate.a = 0.0
	configuracion_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0
	version_label.modulate.a = 0.0
	play_button.scale = Vector2(0.92, 0.92)
	level_select_button.scale = Vector2(0.92, 0.92)
	configuracion_button.scale = Vector2(0.92, 0.92)
	quit_button.scale = Vector2(0.92, 0.92)

	var buttons: Array[Button] = [play_button, level_select_button, configuracion_button, quit_button]
	for btn in buttons:
		btn.mouse_entered.connect(_on_button_hover_in.bind(btn))
		btn.mouse_exited.connect(_on_button_hover_out.bind(btn))
		btn.pressed.connect(_on_button_pressed_sfx)

	# Esperar layout para set pivot_offset al centro de cada botón
	await get_tree().process_frame
	for btn in buttons:
		btn.pivot_offset = btn.size / 2.0

	_animate_entry(buttons)

func _animate_entry(buttons: Array[Button]) -> void:
	# Title: fade 0.8s desde t=0
	var t_title: Tween = create_tween()
	t_title.tween_property(title_label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Subtitle: fade 0.5s desde t=0.3s
	var t_sub: Tween = create_tween()
	t_sub.tween_interval(0.3)
	t_sub.tween_property(subtitle_label, "modulate:a", 1.0, 0.5)

	# Buttons cascada: cada uno arranca a t = 0.6 + i*0.15
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		var t_btn: Tween = create_tween()
		t_btn.tween_interval(0.6 + i * 0.15)
		t_btn.tween_property(btn, "modulate:a", 1.0, 0.4)
		t_btn.parallel().tween_property(btn, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Version: fade desde t=1.4s
	var t_ver: Tween = create_tween()
	t_ver.tween_interval(1.4)
	t_ver.tween_property(version_label, "modulate:a", 1.0, 0.3)

func _on_button_hover_in(btn: Button) -> void:
	AudioManager.play_sfx("ui_hover", 0.0, 0.7)
	var t: Tween = create_tween()
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_hover_out(btn: Button) -> void:
	var t: Tween = create_tween()
	t.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _on_button_pressed_sfx() -> void:
	AudioManager.play_sfx("ui_click")

func _on_play_button_pressed() -> void:
	AudioManager.stop_music(1.0)
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_level_select_button_pressed() -> void:
	level_select_panel.visible = true

func _on_configuracion_button_pressed() -> void:
	AudioManager.stop_music(0.5)
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_panel_back() -> void:
	level_select_panel.visible = false
