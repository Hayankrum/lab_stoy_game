## PersonagemDialogo.gd
## Exibe um personagem flutuante que surge animado (esquerda, direita ou centro)
## e troca de sprite de acordo com os dados da fala no JSON.
##
## ─── Como usar na cena ────────────────────────────────────────────────────────
##   1. Crie um nó TextureRect (ou Sprite2D) dentro do seu painel de diálogo.
##   2. Adicione este script como filho do QuartoController (ou qualquer Control).
##   3. Conecte o export `personagem_rect` ao seu TextureRect.
##   4. No QuartoController, chame `personagem.atualizar(entrada)` dentro de
##      `_processar()`, antes de `await _exibir(...)`.
##
## ─── Campos suportados no JSON (por fala) ────────────────────────────────────
##   "personagem": "res://Assets/personagens/jeane_feliz.png"
##       → troca a imagem do personagem
##
##   "personagem_posicao": "esquerda" | "direita" | "centro"
##       → reposiciona o personagem na tela (com animação de entrada)
##
##   "personagem_ocultar": true
##       → some o personagem com fade-out
##
## ─── Exemplo de entrada JSON ──────────────────────────────────────────────────
##   {
##     "fala": "Oi, tudo bem?",
##     "personagem": "res://Assets/personagens/prof_jeane_normal.png",
##     "personagem_posicao": "esquerda"
##   },
##   {
##     "fala": "Vamos começar a prova!",
##     "personagem": "res://Assets/personagens/prof_jeane_serio.png"
##   },
##   {
##     "fala": "...",
##     "personagem_ocultar": true
##   }

extends Node
class_name PersonagemDialogo

# ─────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────

## O TextureRect que exibirá o sprite do personagem.
## Deve estar posicionado dentro do painel de diálogo.
@export var personagem_rect: TextureRect

## Velocidade do fade de entrada/saída (segundos)
@export var velocidade_fade: float = 0.25

## Distância da animação de entrada em px (o personagem "desliza" até a posição)
@export var distancia_entrada: float = 60.0

## Posição Y base do personagem (em pixels, relativa ao pai)
@export var posicao_y: float = 0.0

## Posições X para cada âncora (ajuste conforme o layout da sua cena)
@export var pos_x_esquerda: float = 60.0
@export var pos_x_direita:  float = 860.0
@export var pos_x_centro:   float = 460.0

## Amplitude do balanço flutuante (px)
@export var flutuacao_amplitude: float = 6.0

## Velocidade do balanço flutuante (segundos por ciclo completo)
@export var flutuacao_velocidade: float = 2.2

# ─────────────────────────────────────────────
# ESTADO INTERNO
# ─────────────────────────────────────────────

var _posicao_atual: String = ""   # "esquerda" | "direita" | "centro"
var _visivel       := false
var _tween_flut: Tween = null     # tween do balanço contínuo
var _tween_anim: Tween = null     # tween de entrada/saída

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────

func _ready() -> void:
	if personagem_rect:
		personagem_rect.modulate.a = 0.0
		personagem_rect.visible    = false

# ─────────────────────────────────────────────
# API PRINCIPAL
# ─────────────────────────────────────────────

## Chame isto em QuartoController._processar(), passando a entrada atual.
## Retorna imediatamente (não precisa de await).
func atualizar(entrada: Dictionary) -> void:
	if not personagem_rect:
		return

	# 1. Ocultar personagem
	if entrada.get("personagem_ocultar", false):
		_ocultar()
		return

	# 2. Trocar imagem se informada
	if entrada.has("personagem"):
		var caminho: String = entrada["personagem"]
		var tex = load(caminho)
		if tex:
			personagem_rect.texture = tex
		else:
			push_warning("PersonagemDialogo: imagem não encontrada: '%s'" % caminho)

	# 3. Reposicionar / mostrar se posição informada
	if entrada.has("personagem_posicao"):
		var nova_pos: String = entrada["personagem_posicao"]
		_mostrar_em(nova_pos)
	elif entrada.has("personagem") and not _visivel:
		# Imagem definida mas sem posição explícita → usa última ou esquerda
		_mostrar_em(_posicao_atual if _posicao_atual != "" else "esquerda")

# ─────────────────────────────────────────────
# MOSTRAR / OCULTAR
# ─────────────────────────────────────────────

func _mostrar_em(posicao: String) -> void:
	_parar_tweens()

	var alvo_x := _x_para_posicao(posicao)
	var origem_x := alvo_x

	# Define de onde o personagem "entra" deslizando
	match posicao:
		"esquerda": origem_x = alvo_x - distancia_entrada
		"direita":  origem_x = alvo_x + distancia_entrada
		"centro":
			# Entra de onde estava antes, ou do centro
			if _posicao_atual == "esquerda":
				origem_x = alvo_x - distancia_entrada
			else:
				origem_x = alvo_x + distancia_entrada

	personagem_rect.visible    = true
	personagem_rect.position.x = origem_x
	personagem_rect.position.y = posicao_y
	personagem_rect.modulate.a = 0.0

	_posicao_atual = posicao
	_visivel       = true

	# Animação de entrada: desliza + fade-in
	_tween_anim = personagem_rect.create_tween()
	_tween_anim.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_anim.tween_property(personagem_rect, "position:x", alvo_x,          velocidade_fade * 2.0)
	_tween_anim.parallel().tween_property(personagem_rect, "modulate:a", 1.0,  velocidade_fade)

	# Após a entrada, inicia o balanço flutuante
	_tween_anim.tween_callback(_iniciar_flutuacao)

func _ocultar() -> void:
	if not _visivel:
		return

	_parar_tweens()
	_visivel = false

	_tween_anim = personagem_rect.create_tween()
	_tween_anim.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween_anim.tween_property(personagem_rect, "modulate:a", 0.0, velocidade_fade)
	_tween_anim.tween_callback(func(): personagem_rect.visible = false)

# ─────────────────────────────────────────────
# FLUTUAÇÃO CONTÍNUA
# ─────────────────────────────────────────────

func _iniciar_flutuacao() -> void:
	if not _visivel or not personagem_rect:
		return

	var base_y := personagem_rect.position.y

	_tween_flut = personagem_rect.create_tween()
	_tween_flut.set_loops()
	_tween_flut.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_flut.tween_property(
		personagem_rect, "position:y",
		base_y - flutuacao_amplitude,
		flutuacao_velocidade / 2.0
	)
	_tween_flut.tween_property(
		personagem_rect, "position:y",
		base_y + flutuacao_amplitude,
		flutuacao_velocidade / 2.0
	)

# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

func _parar_tweens() -> void:
	if _tween_flut and _tween_flut.is_valid():
		_tween_flut.kill()
	if _tween_anim and _tween_anim.is_valid():
		_tween_anim.kill()
	# Reseta Y para não acumular offset de flutuação
	if personagem_rect:
		personagem_rect.position.y = posicao_y

func _x_para_posicao(posicao: String) -> float:
	match posicao:
		"esquerda": return pos_x_esquerda
		"direita":  return pos_x_direita
		"centro":   return pos_x_centro
	push_warning("PersonagemDialogo: posição desconhecida '%s', usando esquerda." % posicao)
	return pos_x_esquerda
