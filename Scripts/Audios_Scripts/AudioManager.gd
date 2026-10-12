## AudioManager.gd
## AudioLoad singleton — réplica fiel do AudioEngine do nova_base.html
## Síntese procedural idêntica: mesmas notas, volumes, envelopes e reverb.
## Música ambiente reescrita em estilo lo-fi: lenta, melancólica, respirada.

extends Node

# ─── Estado público ───────────────────────────────────────────────────────────

var music_volume: float = 0.55   # 0.0–1.0  (equivale a cfgMusicVol/100)
var sfx_volume:   float = 0.75   # 0.0–1.0  (equivale a cfgSfxVol/100)
var music_on:     bool  = true
var sfx_on:       bool  = true

# ─── Constantes ───────────────────────────────────────────────────────────────

const CONFIG_PATH := "user://config.cfg"
const BUS_MUSIC   := "Music"
const BUS_SFX     := "SFX"

## Escala de Dó menor natural — melancólica e lo-fi
## C D Eb F G Ab Bb  (oitavas 3 e 4, graves e mornas)
const NOTES := [
	130.8, 146.8, 155.6, 174.6, 196.0,
	207.7, 233.1, 261.6, 293.7, 311.1
]

## Baixo lo-fi — raiz e quinta, oitava 2, muito grave
const NOTES_BASS := [
	65.4, 73.4, 87.3, 98.0, 103.8
]

# ─── Estado interno ───────────────────────────────────────────────────────────

var _music_active: bool           = false
var _music_timer:  SceneTreeTimer = null

# ─── Inicialização ────────────────────────────────────────────────────────────

func _ready() -> void:
	# Apaga config.cfg corrompido de testes anteriores e regrava com valores padrão
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/config.cfg")
	salvar_config()
	carregar_config()
	if music_on:
		start_music()

# ─── Música ───────────────────────────────────────────────────────────────────

func start_music() -> void:
	if _music_active:
		return
	_music_active = true
	_ambient()

func stop_music() -> void:
	_music_active = false
	_music_timer  = null

func set_music_volume(valor: float) -> void:
	music_volume = valor

# ─── SFX públicos ─────────────────────────────────────────────────────────────

func sfx_click() -> void:
	if not sfx_on: return
	# sine 820 Hz, vol 0.28, dur 0.07 — idêntico ao HTML
	var p := _make_player(BUS_SFX, 0.15)
	_fill_envelope(p.get_stream_playback(), 820.0, 0.07, sfx_volume * 0.28, "sine")
	_auto_free(p, 0.15)

func sfx_reveal() -> void:
	if not sfx_on: return
	# triangle sweep 220→520 Hz, vol 0.38, dur 0.38
	var p := _make_player(BUS_SFX, 0.5)
	_fill_sweep(p.get_stream_playback(), 220.0, 520.0, 0.38, sfx_volume * 0.38, "triangle")
	_auto_free(p, 0.5)

func sfx_dialog() -> void:
	if not sfx_on: return
	# dois tons: 440 e 560 Hz, vol 0.16, dur 0.13
	_play_sfx_delayed(440.0, 0.13, sfx_volume * 0.16, "sine", 0.0)
	_play_sfx_delayed(560.0, 0.13, sfx_volume * 0.16, "sine", 0.07)

func sfx_open() -> void:
	if not sfx_on: return
	# triangle sweep 180→480 Hz, vol 0.30, dur 0.28
	var p := _make_player(BUS_SFX, 0.4)
	_fill_sweep(p.get_stream_playback(), 180.0, 480.0, 0.28, sfx_volume * 0.30, "triangle")
	_auto_free(p, 0.4)

func sfx_correct() -> void:
	if not sfx_on: return
	# três notas C5 E5 G5, vol 0.30
	_play_sfx_delayed(523.3, 0.5, sfx_volume * 0.30, "sine", 0.0)
	_play_sfx_delayed(659.3, 0.5, sfx_volume * 0.30, "sine", 0.14)
	_play_sfx_delayed(784.0, 0.5, sfx_volume * 0.30, "sine", 0.28)

func sfx_wrong() -> void:
	if not sfx_on: return
	# sawtooth sweep 300→190 Hz, vol 0.22, dur 0.28
	var p := _make_player(BUS_SFX, 0.4)
	_fill_sweep(p.get_stream_playback(), 300.0, 190.0, 0.28, sfx_volume * 0.22, "sawtooth")
	_auto_free(p, 0.4)

# ─── Persistência ─────────────────────────────────────────────────────────────

func salvar_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume",   sfx_volume)
	cfg.set_value("audio", "music_on",     music_on)
	cfg.set_value("audio", "sfx_on",       sfx_on)
	cfg.save(CONFIG_PATH)

func carregar_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	music_volume = cfg.get_value("audio", "music_volume", 0.55)
	sfx_volume   = cfg.get_value("audio", "sfx_volume",   0.75)
	music_on     = cfg.get_value("audio", "music_on",     true)
	sfx_on       = cfg.get_value("audio", "sfx_on",       true)

# ─── Música ambiente lo-fi ────────────────────────────────────────────────────
#
# Estética lo-fi: notas longas e suaves em Dó menor, andamento muito lento
# (2–4 s entre eventos), harmonia esparsa, baixo profundo ocasional,
# e eco prolongado simulando fita cassete gasta.
#
# Formas de onda: triangle (quente, sem brilho) no lugar de sine puro,
# o que emula o som ligeiramente "suja" do lo-fi.
#
# Volumes mais baixos e dinâmica suave para não competir com o jogo.

func _ambient() -> void:
	if not _music_active:
		return

	# Nota principal — triangle, longa e suave
	var freq: float = NOTES[randi() % NOTES.size()]
	var dur:  float = 1.4 + randf() * 1.2   # 1.4–2.6 s (respira)
	_play_music_note(freq, dur, music_volume * 0.18, "triangle")

	# Harmonia — 45% de chance, entra com delay como um acorde desmembrado
	if randf() < 0.45:
		var f2: float = NOTES[randi() % NOTES.size()]
		_play_music_note_delayed(f2, 1.2 + randf() * 0.8, music_volume * 0.11, 0.25, "triangle")

	# Baixo profundo — 40% de chance, notas muito longas como um pad
	if randf() < 0.40:
		var fb: float = NOTES_BASS[randi() % NOTES_BASS.size()]
		_play_music_note_delayed(fb, 2.0 + randf() * 1.0, music_volume * 0.16, 0.0, "sine")

	# Eco cassete — repete a nota principal bem mais fraca e atrasada (~0.38 s)
	# Simula o reverb/flutter de fita lo-fi
	_play_music_note_delayed(freq, dur * 0.6, music_volume * 0.04, 0.38, "triangle")

	# Segunda camada de eco bem distante (tape flutter)
	if randf() < 0.35:
		_play_music_note_delayed(freq, dur * 0.4, music_volume * 0.02, 0.72, "triangle")

	# Andamento lento: 2.0–4.0 s entre eventos — dá sensação de respiração lo-fi
	_music_timer = get_tree().create_timer(2.0 + randf() * 2.0)
	_music_timer.timeout.connect(_ambient, CONNECT_ONE_SHOT)

func _play_music_note(freq: float, dur: float, vol: float, type: String = "sine") -> void:
	var p := _make_player(BUS_MUSIC, dur + 0.3)
	_fill_envelope(p.get_stream_playback(), freq, dur, vol, type)
	_auto_free(p, dur + 0.4)

func _play_music_note_delayed(freq: float, dur: float, vol: float, delay: float, type: String = "sine") -> void:
	get_tree().create_timer(delay).timeout.connect(
		func(): _play_music_note(freq, dur, vol, type),
		CONNECT_ONE_SHOT
	)

# ─── Helpers internos ─────────────────────────────────────────────────────────

func _make_player(bus: String, buffer: float) -> AudioStreamPlayer:
	var p   := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate      = 44100.0
	gen.buffer_length = buffer
	p.stream = gen
	p.bus    = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	add_child(p)
	p.play()
	return p

func _auto_free(p: AudioStreamPlayer, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(p.queue_free, CONNECT_ONE_SHOT)

func _play_sfx_delayed(freq: float, dur: float, vol: float, type: String, delay: float) -> void:
	if delay <= 0.0:
		var p := _make_player(BUS_SFX, dur + 0.1)
		_fill_envelope(p.get_stream_playback(), freq, dur, vol, type)
		_auto_free(p, dur + 0.15)
		return
	get_tree().create_timer(delay).timeout.connect(func():
		var p := _make_player(BUS_SFX, dur + 0.1)
		_fill_envelope(p.get_stream_playback(), freq, dur, vol, type)
		_auto_free(p, dur + 0.15)
	, CONNECT_ONE_SHOT)

## Envelope idêntico ao HTML:
##   linearRamp 0→vol nos primeiros 12% (attack)
##   sustain até 55% da duração
##   linearRamp vol→0 até o fim (release)
func _fill_envelope(
	pb:       AudioStreamGeneratorPlayback,
	freq:     float,
	duration: float,
	vol:      float,
	type:     String
) -> void:
	var rate    := 44100
	var samples := int(rate * duration)
	var frames  := PackedVector2Array()
	frames.resize(samples)
	var attack  := int(samples * 0.12)   # 12% = linearRamp nos primeiros 0.12 do HTML
	var sustain := int(samples * 0.55)   # sustain até 55%
	for i in range(samples):
		var t := float(i) / float(rate)
		var s := _wave(type, freq, t)
		var env: float
		if i < attack:
			env = float(i) / float(attack)
		elif i < sustain:
			env = 1.0
		else:
			env = float(samples - i) / float(samples - sustain)
		frames[i] = Vector2(s * vol * env, s * vol * env)
	pb.push_buffer(frames)

## Sweep de frequência com mesmo envelope
func _fill_sweep(
	pb:         AudioStreamGeneratorPlayback,
	freq_start: float,
	freq_end:   float,
	duration:   float,
	vol:        float,
	type:       String
) -> void:
	var rate    := 44100
	var samples := int(rate * duration)
	var frames  := PackedVector2Array()
	frames.resize(samples)
	var attack  := int(samples * 0.12)
	var sustain := int(samples * 0.55)
	var phase   := 0.0
	for i in range(samples):
		var progress := float(i) / float(samples)
		phase += (freq_start + (freq_end - freq_start) * progress) / float(rate) * TAU
		var s := _wave_phase(type, phase)
		var env: float
		if i < attack:
			env = float(i) / float(attack)
		elif i < sustain:
			env = 1.0
		else:
			env = float(samples - i) / float(samples - sustain)
		frames[i] = Vector2(s * vol * env, s * vol * env)
	pb.push_buffer(frames)

func _wave(type: String, freq: float, t: float) -> float:
	return _wave_phase(type, freq * t * TAU)

func _wave_phase(type: String, phase: float) -> float:
	match type:
		"sine":     return sin(phase)
		"triangle":
			var p := fmod(phase / TAU, 1.0)
			return 2.0 * abs(2.0 * p - 1.0) - 1.0
		"sawtooth": return 2.0 * fmod(phase / TAU, 1.0) - 1.0
	return sin(phase)
