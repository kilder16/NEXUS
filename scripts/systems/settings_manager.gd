extends Node

# === SETTINGS MANAGER ===
# Autoload singleton. Maneja persistencia y aplicación de settings gráficos.
# Archivo de configuración: user://settings.cfg
#
# Uso desde cualquier script:
#   SettingsManager.set_fullscreen(true)
#   SettingsManager.set_vsync(false)
#   SettingsManager.set_quality(2)  # 0=Baja, 1=Media, 2=Alta
#
# Los settings se aplican al arrancar el juego automáticamente (_ready)
# y se guardan en disco cada vez que se modifican.

const SETTINGS_PATH := "user://settings.cfg"

# === ESTADO (con defaults) ===
var fullscreen: bool = false
var vsync: bool = true
var quality: int = 1  # 0=Baja, 1=Media, 2=Alta

# Path de la escena a la que volver desde settings_menu. Lo setea el caller
# (ej. pause_menu antes de cambiar de escena). settings_menu lo consume (lo
# limpia a "") en _ready, así no retiene estado stale entre aperturas.
# No se persiste en settings.cfg; solo vive en memoria.
var pending_return_path: String = ""

const QUALITY_NAMES := ["Baja", "Media", "Alta"]

signal settings_changed

func _ready():
	load_settings()
	# Aplicar después de 1 frame para asegurar que el viewport esté listo
	await get_tree().process_frame
	apply_all()

# ============================================================================
# PERSISTENCIA
# ============================================================================

func load_settings():
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		print("[Settings] No hay settings guardados, usando defaults")
		save_settings()
		return
	
	fullscreen = cfg.get_value("graphics", "fullscreen", false)
	vsync = cfg.get_value("graphics", "vsync", true)
	quality = cfg.get_value("graphics", "quality", 1)
	print("[Settings] Cargados: fullscreen=", fullscreen, " vsync=", vsync, " quality=", QUALITY_NAMES[quality])

func save_settings():
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "quality", quality)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("[Settings] No se pudo guardar settings.cfg: error " + str(err))

# ============================================================================
# APLICACIÓN
# ============================================================================

func apply_all():
	apply_fullscreen()
	apply_vsync()
	apply_quality()
	settings_changed.emit()

func apply_fullscreen():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func apply_vsync():
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func apply_quality():
	var viewport := get_viewport()
	if viewport == null:
		return
	
	match quality:
		0:  # Baja
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		1:  # Media
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 1.0
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2:  # Alta
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

# ============================================================================
# SETTERS PÚBLICOS (llamados desde la UI del settings_menu)
# ============================================================================

func set_fullscreen(value: bool):
	fullscreen = value
	apply_fullscreen()
	save_settings()
	settings_changed.emit()

func set_vsync(value: bool):
	vsync = value
	apply_vsync()
	save_settings()
	settings_changed.emit()

func set_quality(value: int):
	quality = clamp(value, 0, 2)
	apply_quality()
	save_settings()
	settings_changed.emit()
