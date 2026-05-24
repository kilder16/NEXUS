extends Control

# === NEXUS - Panel de selección de nivel (overlay) ===

signal back_pressed

const LEVEL_PATHS := {
	1: "res://scenes/levels/level_01.tscn",
	2: "res://scenes/levels/level_02.tscn",
	3: "res://scenes/levels/level_03.tscn",
	4: "res://scenes/levels/level_04.tscn",
	5: "res://scenes/levels/level_05.tscn",
}

func _ready() -> void:
	visible = false
	# Conectar hover SFX a todos los botones recursivamente
	_wire_hover_sfx(self)

func _wire_hover_sfx(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.mouse_entered.connect(_on_any_button_hover)
		_wire_hover_sfx(child)

func _on_any_button_hover() -> void:
	AudioManager.play_sfx("ui_hover", 0.0, 0.7)

func _on_level_1_pressed() -> void: _load_level(1)
func _on_level_2_pressed() -> void: _load_level(2)
func _on_level_3_pressed() -> void: _load_level(3)
func _on_level_4_pressed() -> void: _load_level(4)
func _on_level_5_pressed() -> void: _load_level(5)

func _load_level(num: int) -> void:
	AudioManager.play_sfx("ui_click")
	AudioManager.stop_music(1.0)
	get_tree().change_scene_to_file(LEVEL_PATHS[num])

func _on_back_pressed_button() -> void:
	AudioManager.play_sfx("ui_click")
	back_pressed.emit()
	visible = false
