extends Node

# === NEXUS - Audio Manager (autoload singleton) ===
# Reproduce SFX vía pool de AudioStreamPlayers para sonidos simultáneos.
# Reproduce música con fade in/out controlado por Tween.
# Genera WAVs placeholder en primer launch; los guarda a disco y los reusa.
# Cuando el usuario reemplaza los archivos en audio/ con WAVs reales,
# AudioManager los detecta automáticamente y usa los reales.

const SFX_POOL_SIZE: int = 8
const MUSIC_FADE_DEFAULT: float = 2.0
const MUSIC_MIN_DB: float = -60.0
# TEMPORAL: pon en false tras confirmar que el audio suena bien.
# true → regenera TODOS los WAVs procedurales en cada launch (ignora cache en disco).
const FORCE_REGEN: bool = false

const SFX_DIR: String = "res://audio/sfx/"
const MUSIC_DIR: String = "res://audio/music/"

var _sfx_streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _sfx_pool: Array = []
var _sfx_pool_index: int = 0
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _rng: RandomNumberGenerator

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42  # reproducible: misma "huella" del placeholder en todas las máquinas
	_ensure_buses()
	_setup_pools()
	_setup_streams()

func _ensure_buses() -> void:
	# Defensa: si el bus_layout no carga (timing de import en Godot, archivo recién creado,
	# editor que cacheó el layout previo, etc.), creamos Music y SFX en runtime.
	# Idempotente: no toca buses que ya existan con el nombre correcto.
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx_music: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx_music, "Music")
		AudioServer.set_bus_volume_db(idx_music, -8.0)
		AudioServer.set_bus_send(idx_music, "Master")
		print("[AudioManager] Bus 'Music' creado en runtime (no estaba en bus_layout)")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx_sfx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx_sfx, "SFX")
		AudioServer.set_bus_volume_db(idx_sfx, -3.0)
		AudioServer.set_bus_send(idx_sfx, "Master")
		print("[AudioManager] Bus 'SFX' creado en runtime (no estaba en bus_layout)")

func _setup_pools() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

func _setup_streams() -> void:
	_sfx_streams["shot"] = _ensure_stream(SFX_DIR + "shot.wav", _gen_shot)
	_sfx_streams["hit"] = _ensure_stream(SFX_DIR + "hit.wav", _gen_hit)
	_sfx_streams["enemy_death"] = _ensure_stream(SFX_DIR + "enemy_death.wav", _gen_enemy_death)
	_sfx_streams["victory"] = _ensure_stream(SFX_DIR + "victory.wav", _gen_victory)
	_music_streams["menu_music"] = _ensure_stream(MUSIC_DIR + "menu_music.wav", _gen_menu_music, true)

func _ensure_stream(path: String, generator: Callable, is_music: bool = false) -> AudioStreamWAV:
	var stream: AudioStreamWAV = null
	if not FORCE_REGEN and ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is AudioStreamWAV:
			stream = loaded
	if stream == null:
		stream = generator.call()
		var globalized: String = ProjectSettings.globalize_path(path)
		var dir: String = ProjectSettings.globalize_path(path.get_base_dir())
		DirAccess.make_dir_recursive_absolute(dir)
		var err: int = stream.save_to_wav(globalized)
		if err != OK:
			push_warning("[AudioManager] No se pudo guardar WAV: %s (err=%d)" % [globalized, err])
		else:
			print("[AudioManager] Placeholder generado: ", path)
	# El importador de WAV de Godot descarta loop_mode por default (edit/loop_mode=0).
	# Re-aplicamos en runtime para streams de música. Funciona con sample comprimido (QOA)
	# porque get_length() y mix_rate sobreviven la compresión.
	if is_music:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream

# ============================================================
# API pública
# ============================================================

func play_sfx(snd_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sfx_streams.has(snd_name):
		push_warning("[AudioManager] SFX no encontrado: " + snd_name)
		return
	var p := _get_free_sfx_player()
	p.stream = _sfx_streams[snd_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

func play_sfx_pitched(snd_name: String, volume_db: float = 0.0) -> void:
	var pitch: float = randf_range(0.95, 1.05)
	play_sfx(snd_name, volume_db, pitch)

func play_music(snd_name: String, fade_in: float = MUSIC_FADE_DEFAULT) -> void:
	if not _music_streams.has(snd_name):
		push_warning("[AudioManager] Música no encontrada: " + snd_name)
		return
	var stream: AudioStreamWAV = _music_streams[snd_name]
	print("[AudioManager] play_music: %s bus=%s length=%.2fs loop=%d loop_end=%d" % [
		snd_name, _music_player.bus, stream.get_length(), stream.loop_mode, stream.loop_end
	])
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	_music_player.stream = stream
	_music_player.volume_db = MUSIC_MIN_DB
	_music_player.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", 0.0, fade_in)

func stop_music(fade_out: float = MUSIC_FADE_DEFAULT) -> void:
	if not _music_player.playing:
		return
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", MUSIC_MIN_DB, fade_out)
	_music_tween.tween_callback(_music_player.stop)

# ============================================================
# Internos: pool, helpers de síntesis
# ============================================================

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	return p

func _write_sample(data: PackedByteArray, idx: int, s: float) -> void:
	var clamped: float = clamp(s, -0.95, 0.95)  # anti-clip
	var s16: int = int(clamped * 32767.0)
	if s16 < 0:
		s16 += 65536  # signed → unsigned para encoding little-endian
	data[idx * 2] = s16 & 0xFF
	data[idx * 2 + 1] = (s16 >> 8) & 0xFF

func _env_ad(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / decay)

func _soft_clip(s: float, threshold: float) -> float:
	if s > threshold:
		return threshold + (1.0 - threshold) * tanh((s - threshold) / (1.0 - threshold))
	if s < -threshold:
		return -threshold + (1.0 - threshold) * tanh((s + threshold) / (1.0 - threshold))
	return s

func _build_stream(data: PackedByteArray, sr: int, loop: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sr
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2  # total de samples mono
	return stream

# ============================================================
# Generadores procedurales (todas las síntesis verificadas anti-clip)
# ============================================================

func _gen_shot() -> AudioStreamWAV:
	var sr := 44100
	var dur := 0.08
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / sr
		var noise: float = _rng.randf_range(-1.0, 1.0)
		var env_n: float = _env_ad(t, 0.002, 0.030)
		var tonal: float = sin(TAU * 2400.0 * t) * _env_ad(t, 0.001, 0.015)
		var s: float = noise * env_n * 0.7 + tonal * 0.3
		_write_sample(data, i, s * 0.85)
	return _build_stream(data, sr)

func _gen_hit() -> AudioStreamWAV:
	var sr := 44100
	var dur := 0.15
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t: float = float(i) / sr
		var freq: float = lerp(110.0, 70.0, t / dur)
		phase += TAU * freq / sr
		var env: float = _env_ad(t, 0.005, 0.080)
		var s: float = sin(phase) * env * 1.5
		s = _soft_clip(s, 0.7)
		_write_sample(data, i, s)
	return _build_stream(data, sr)

func _gen_enemy_death() -> AudioStreamWAV:
	var sr := 44100
	var dur := 0.3
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t: float = float(i) / sr
		var freq: float = lerp(200.0, 80.0, t / dur)
		phase += TAU * freq / sr
		var noise: float = _rng.randf_range(-1.0, 1.0)
		# bit-crush noise a ~6-bit para feel glitch
		noise = floor(noise * 32.0) / 32.0
		var env_n: float = _env_ad(t, 0.010, 0.250)
		var tonal: float = sin(phase) * _env_ad(t, 0.005, 0.200)
		var s: float = (noise * 0.4 + tonal * 0.6) * env_n
		_write_sample(data, i, s * 0.9)
	return _build_stream(data, sr)

func _gen_victory() -> AudioStreamWAV:
	var sr := 44100
	var dur := 2.0
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / sr
		var s: float = 0.0
		# Tríada mayor arpeggiada: 440 Hz, 660 Hz (+0.3s), 880 Hz (+0.6s)
		s += sin(TAU * 440.0 * t) * _env_ad(t, 0.020, 1.500) * 0.40
		if t > 0.3:
			s += sin(TAU * 660.0 * (t - 0.3)) * _env_ad(t - 0.3, 0.020, 1.500) * 0.35
		if t > 0.6:
			s += sin(TAU * 880.0 * (t - 0.6)) * _env_ad(t - 0.6, 0.020, 1.500) * 0.30
		_write_sample(data, i, s * 0.75)
	return _build_stream(data, sr)

func _gen_menu_music() -> AudioStreamWAV:
	# Tríada A mayor (A3=220, C#4=277, E4=330) — audible en bocinas de laptop que cortan <100 Hz.
	# Loop seamless: 220/277/330 × 12 = 2640/3324/3960 ciclos (todos enteros).
	# LFOs a 1/12 y 2/12 Hz dan 1 y 2 ciclos por loop. Cero pop en boundary.
	var sr := 44100
	var dur := 12.0
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t: float = float(i) / sr
		var d1: float = sin(TAU * 220.0 * t) * 0.30
		var d2: float = sin(TAU * 277.0 * t) * 0.22
		var d3: float = sin(TAU * 330.0 * t) * 0.25
		var lfo1: float = 0.5 + 0.5 * sin(TAU * (1.0/12.0) * t)
		var lfo2: float = 0.5 + 0.5 * sin(TAU * (2.0/12.0) * t)
		var s: float = d1 * lfo1 + d2 * 0.7 + d3 * lfo2
		_write_sample(data, i, s * 0.85)
	return _build_stream(data, sr, true)
