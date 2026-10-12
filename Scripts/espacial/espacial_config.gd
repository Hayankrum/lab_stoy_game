## EspacialController.gd

extends Control

# ─── Exports ──────────────────────────────────────────────────────────────────

@export var mundo:         Control
@export var botao_avancar: TextureButton
@export var quarto:        QuartoController

## Arraste o nó TelaFinal aqui. Tipo Control evita erro de export no Inspector.
@export var tela_final: Control

# ─── Layouts (PackedScene) ────────────────────────────────────────────────────

@export var bloco_esquerda: PackedScene
@export var bloco_direita:  PackedScene
@export var bloco_cima:     PackedScene
@export var bloco_baixo:    PackedScene

# ─── JSON ─────────────────────────────────────────────────────────────────────

@export_file("*.json") var arquivo_json: String

# ─── Config ───────────────────────────────────────────────────────────────────

@export_group("Velocidades")
@export var velocidade_texto      := 0.02
@export var velocidade_camera     := 1.2
@export var velocidade_zoom_final := 3.0

@export_group("Imagem")
@export var tamanho_quadrado   := 220
@export var tamanho_horizontal := Vector2(320, 180)
@export var tamanho_vertical   := Vector2(180, 320)

@export_group("Camera")
@export var tamanho_camera_bloco := Vector2(300, 200)

@export_group("Interativo")
@export var intensidade_balanco := 2.0
@export var velocidade_balanco  := 1.0
@export var escala_balanco      := 1.03

@export_group("Final")
@export var padding_historia := 500.0

@export_group("Botao")
@export var alpha_botao_bloqueado := 0.35

# ─── Sistemas ─────────────────────────────────────────────────────────────────

var narrativa := NarrativeSystem.new()
var _wipe: Node

# ─── Estado ───────────────────────────────────────────────────────────────────

var _dados:        Dictionary = {}
var _trilha_atual: String     = "principal"
var _indice:       int        = 0

var _ocupado:      bool = false
var _pode_avancar: bool = false
var _em_quarto:    bool = false
var _escrevendo:   bool = false

# ─── Inicialização ────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.start_music()
	_wipe = get_node("/root/TransicaoWipe")
	add_to_group("espacial")
	add_child(narrativa)

	botao_avancar.visible    = false
	botao_avancar.modulate.a = 0.0
	botao_avancar.pressed.connect(_avancar)

	if quarto:
		quarto.fechado.connect(_quarto_fechado)

	_dados = _carregar_json(arquivo_json)

	if _dados.is_empty():
		push_error("EspacialController: JSON não carregado.")
		return

	_criar_bloco()

# ─── JSON ─────────────────────────────────────────────────────────────────────

func _carregar_json(path: String) -> Dictionary:
	if path.is_empty():
		push_error("EspacialController: arquivo_json não definido.")
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("EspacialController: erro ao abrir '%s'." % path)
		return {}

	var resultado = JSON.parse_string(file.get_as_text())
	if not resultado is Dictionary:
		push_error("EspacialController: JSON inválido em '%s'." % path)
		return {}

	return resultado

# ─── Trilha e blocos ──────────────────────────────────────────────────────────

func _bloco_atual() -> Variant:
	var trilhas: Dictionary = _dados.get("trilhas", {})

	if not trilhas.has(_trilha_atual):
		push_error("EspacialController: trilha '%s' não encontrada." % _trilha_atual)
		return null

	var blocos: Array = trilhas[_trilha_atual]

	if _indice >= blocos.size():
		return null

	return blocos[_indice]

# ─── Criar bloco ──────────────────────────────────────────────────────────────

func _criar_bloco() -> void:
	if _ocupado:
		return

	var dados_bloco = _bloco_atual()

	if dados_bloco == null:
		# Trilha terminou — resolve final com await
		await _esconder_botao()
		await _mostrar_historia_completa()
		await _resolver_final()
		return

	if not _validar_bloco(dados_bloco):
		return

	_ocupado = true

	await _esconder_botao()

	var layout:      String      = dados_bloco.get("layout", "")
	var cena_layout: PackedScene = _pegar_layout(layout)

	if cena_layout == null:
		_ocupado = false
		return

	var bloco = cena_layout.instantiate()
	mundo.add_child(bloco)
	bloco.position = Vector2(
		dados_bloco.get("posicao_x", 0),
		dados_bloco.get("posicao_y", 0)
	)

	var img: TextureButton = bloco.find_child("img_conteudo", true, false)
	var txt: RichTextLabel = bloco.find_child("txt_conteudo", true, false)

	if img == null or txt == null:
		push_error("EspacialController: img_conteudo ou txt_conteudo não encontrado.")
		_ocupado = false
		return

	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for filho in bloco.get_children():
		if filho is Control and filho != img:
			filho.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var caminho_img: String = dados_bloco.get("imagem", "")
	if caminho_img != "":
		img.texture_normal = load(caminho_img)

	_configurar_tamanho_imagem(img, dados_bloco.get("tipo", "quadrado"))
	img.disabled     = false
	img.mouse_filter = Control.MOUSE_FILTER_STOP

	txt.clear()

	await _mover_camera_para(bloco.position)

	_animar_entrada_bloco(bloco)
	await get_tree().create_timer(0.35).timeout

	await _escrever_texto(txt, dados_bloco.get("texto", ""), layout)

	if dados_bloco.get("interativo", false):
		_ativar_bloco_interativo(img, dados_bloco.get("quarto", ""))
	else:
		_pode_avancar = true

	_mostrar_botao()
	_ocupado = false

# ─── Animações ────────────────────────────────────────────────────────────────

func _animar_entrada_bloco(bloco: Node) -> void:
	AudioManager.sfx_reveal()

	bloco.modulate.a = 0.0
	bloco.scale      = Vector2(0.94, 0.94)

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(bloco, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(bloco, "scale", Vector2.ONE, 0.35)

# ─── Bloco interativo ─────────────────────────────────────────────────────────

func _ativar_bloco_interativo(img: TextureButton, id_quarto: String) -> void:
	_pode_avancar = false

	img.ignore_texture_size = true
	img.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var tw = create_tween()
	tw.set_loops()
	tw.tween_property(img, "rotation_degrees",  intensidade_balanco, velocidade_balanco)
	tw.parallel().tween_property(img, "scale", Vector2(escala_balanco, escala_balanco), velocidade_balanco)
	tw.tween_property(img, "rotation_degrees", -intensidade_balanco, velocidade_balanco)
	tw.parallel().tween_property(img, "scale", Vector2.ONE, velocidade_balanco)

	img.pressed.connect(
		_on_bloco_clicado.bind(img, tw, id_quarto),
		CONNECT_ONE_SHOT
	)

	_atualizar_visual_botao()

# ─── Abrir quarto (com wipe) ──────────────────────────────────────────────────

func _on_bloco_clicado(
	img:        TextureButton,
	tw_balanco: Tween,
	id_quarto:  String
) -> void:
	if _em_quarto:
		return

	tw_balanco.kill()
	img.rotation_degrees = 0.0
	img.scale            = Vector2.ONE
	img.disabled         = true

	_em_quarto    = true
	_pode_avancar = false

	await _esconder_botao()
	AudioManager.sfx_open()

	await _wipe.fechar()
	quarto.abrir(id_quarto, _dados, narrativa)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wipe.abrir()

# ─── Retorno do quarto ────────────────────────────────────────────────────────

func _quarto_fechado(resultado: Dictionary) -> void:
	_em_quarto = false

	var ram: String = resultado.get("ramificacao", "")

	if ram != "" and ram != _trilha_atual:
		var trilhas: Dictionary = _dados.get("trilhas", {})

		if trilhas.has(ram):
			_trilha_atual = ram
			_indice       = 0
		else:
			push_error(
				"EspacialController: ramificação '%s' não existe no JSON." % ram
			)
	else:
		_indice += 1

	_criar_bloco()

# ─── Avançar ──────────────────────────────────────────────────────────────────

func _avancar() -> void:
	if _ocupado or _em_quarto:
		return

	if _escrevendo:
		_escrevendo = false
		return

	if not _pode_avancar:
		return

	_pode_avancar = false
	_indice      += 1
	_criar_bloco()

func _input(evento: InputEvent) -> void:
	if _em_quarto:
		return

	if evento.is_action_pressed("ui_accept"):
		_avancar()

# ─── Botão avançar ────────────────────────────────────────────────────────────

func _mostrar_botao() -> void:
	if _em_quarto:
		return

	botao_avancar.visible = true

	var alpha_alvo := 1.0 if _pode_avancar else alpha_botao_bloqueado

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(botao_avancar, "modulate:a", alpha_alvo, 0.25)

func _esconder_botao() -> void:
	var tw = create_tween()
	tw.tween_property(botao_avancar, "modulate:a", 0.0, 0.2)
	await tw.finished
	botao_avancar.visible = false

func _atualizar_visual_botao() -> void:
	if not botao_avancar.visible:
		return

	var alpha_alvo := 1.0 if _pode_avancar else alpha_botao_bloqueado

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(botao_avancar, "modulate:a", alpha_alvo, 0.25)

# ─── Câmera ───────────────────────────────────────────────────────────────────

func _mover_camera_para(pos: Vector2) -> void:
	var tela   := get_viewport_rect().size
	var centro := pos + tamanho_camera_bloco / 2.0
	var alvo   := -centro + tela / 2.0

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mundo, "position", alvo, velocidade_camera)
	await tw.finished

# ─── Zoom final ───────────────────────────────────────────────────────────────

func _mostrar_historia_completa() -> void:
	_pode_avancar         = false
	botao_avancar.visible = false

	var filhos := mundo.get_children()

	if filhos.is_empty():
		return

	await get_tree().process_frame

	var menor_x: float = INF
	var menor_y: float = INF
	var maior_x: float = -INF
	var maior_y: float = -INF

	for bloco in filhos:
		if not bloco is Control:
			continue

		var controle: Control = bloco
		var rect: Rect2       = controle.get_global_rect()

		menor_x = min(menor_x, controle.position.x)
		menor_y = min(menor_y, controle.position.y)
		maior_x = max(maior_x, controle.position.x + rect.size.x)
		maior_y = max(maior_y, controle.position.y + rect.size.y)

	var largura: float = maior_x - menor_x
	var altura:  float = maior_y - menor_y

	var centro := Vector2(
		menor_x + largura / 2.0,
		menor_y + altura  / 2.0
	)

	var tela: Vector2 = get_viewport_rect().size

	var escala: float = clamp(
		min(
			tela.x / (largura + padding_historia),
			tela.y / (altura  + padding_historia)
		),
		0.15,
		1.0
	)

	var alvo := tela / 2.0 - centro * escala

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mundo, "position", alvo,                            velocidade_zoom_final)
	tw.parallel().tween_property(mundo, "scale", Vector2(escala, escala), velocidade_zoom_final)

	await tw.finished

# ─── Final ────────────────────────────────────────────────────────────────────

func _resolver_final() -> void:
	print(">>> _resolver_final chamado")

	var finais: Array = _dados.get("finais", [])
	print(">>> finais no JSON: ", finais.size())

	var resultado := narrativa.resolver_final(finais)
	print(">>> resultado: ", resultado)

	if resultado.is_empty():
		push_error("EspacialController: resolver_final retornou vazio.")
		return

	botao_avancar.visible = false

	if tela_final == null:
		push_error("EspacialController: tela_final é null — arraste o nó no Inspector.")
		return

	print(">>> tela_final encontrado: ", tela_final.name)
	print(">>> tem método mostrar: ", tela_final.has_method("mostrar"))

	if not tela_final.has_method("mostrar"):
		push_error("EspacialController: tela_final não tem método 'mostrar' — verifique se o script TelaFinal.gd está anexado ao nó.")
		return

	await get_tree().process_frame
	await tela_final.mostrar(resultado, narrativa)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _validar_bloco(dados_bloco: Dictionary) -> bool:
	var obrigatorios := ["layout", "tipo", "imagem", "texto", "posicao_x", "posicao_y"]

	for campo in obrigatorios:
		if not dados_bloco.has(campo):
			push_error(
				"EspacialController: campo obrigatório ausente no bloco %d da trilha '%s': '%s'"
				% [_indice, _trilha_atual, campo]
			)
			return false

	return true

func _pegar_layout(layout: String) -> PackedScene:
	match layout:
		"esquerda": return bloco_esquerda
		"direita":  return bloco_direita
		"cima":     return bloco_cima
		"baixo":    return bloco_baixo

	push_error("EspacialController: layout desconhecido: '%s'" % layout)
	return null

func _configurar_tamanho_imagem(img: TextureButton, tipo: String) -> void:
	match tipo:
		"quadrado":
			img.custom_minimum_size = Vector2(tamanho_quadrado, tamanho_quadrado)
		"horizontal":
			img.custom_minimum_size = tamanho_horizontal
		"vertical":
			img.custom_minimum_size = tamanho_vertical
		_:
			push_error("EspacialController: tipo de imagem desconhecido: '%s'" % tipo)

	img.ignore_texture_size = true
	img.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

func _escrever_texto(
	label:  RichTextLabel,
	texto:  String,
	layout: String
) -> void:
	_escrevendo = true
	var atual   := ""

	var reverso := layout == "esquerda" or layout == "cima"

	if reverso:
		for i in range(texto.length() - 1, -1, -1):
			if not _escrevendo:
				label.clear()
				label.append_text(texto)
				_escrevendo = false
				return

			atual = texto[i] + atual
			label.clear()
			label.append_text(atual)
			await get_tree().create_timer(velocidade_texto).timeout
	else:
		for letra in texto:
			if not _escrevendo:
				label.clear()
				label.append_text(texto)
				_escrevendo = false
				return

			atual += letra
			label.clear()
			label.append_text(atual)
			await get_tree().create_timer(velocidade_texto).timeout

	_escrevendo = false
