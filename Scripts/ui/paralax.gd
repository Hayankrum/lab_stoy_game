## ParallaxQuarto.gd
## Parallax com efeito de flutuação estilo mar

extends TextureRect

# ── Parallax ─────────────────────────────────
@export var intensidade: Vector2 = Vector2(40.0, 25.0)
@export var suavizacao: float = 0.07
@export var ativo: bool = true

# ── Flutuação ────────────────────────────────
@export var flutuacao_ativa: bool = true
@export var amplitude_flutuacao: Vector2 = Vector2(12.0, 8.0)
@export var velocidade_flutuacao: float = 2

# Rotação suave
@export var intensidade_rotacao: float = 0.01

# ── Interno ──────────────────────────────────
var _base: Vector2 = Vector2.ZERO
var _viewport: Viewport
var _pronto: bool = false
var _tempo: float = 0.0

func _ready() -> void:
	_viewport = get_viewport()

	# Espera layout finalizar
	await get_tree().process_frame
	await get_tree().process_frame

	recentrar()
	_pronto = true

func _process(delta: float) -> void:
	if not _pronto or not ativo:
		return

	_tempo += delta * velocidade_flutuacao

	var vp_size: Vector2 = _viewport.get_visible_rect().size
	var mouse: Vector2 = _viewport.get_mouse_position()

	# Mouse normalizado
	var norm := mouse / vp_size * 2.0 - Vector2.ONE

	# Movimento do parallax
	var alvo := _base - norm * intensidade

	# ── Flutuação estilo mar ─────────────────
	if flutuacao_ativa:
		var flutuar := Vector2(
			sin(_tempo * 0.8) * amplitude_flutuacao.x,
			cos(_tempo * 0.6) * amplitude_flutuacao.y
		)

		alvo += flutuar

		# Rotação suave
		rotation = sin(_tempo * 0.5) * intensidade_rotacao
	else:
		rotation = 0.0

	# Movimento suave
	position = position.lerp(alvo, suavizacao)

# ── Público ──────────────────────────────────

func recentrar() -> void:
	var pai_size: Vector2 = get_parent_control().size
	_base = (pai_size - size) * 0.5
	position = _base

func set_ativo(valor: bool) -> void:
	ativo = valor

	if not ativo:
		position = _base
		rotation = 0.0
