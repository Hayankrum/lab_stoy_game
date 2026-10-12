## QuartoController.gd
## ✅ Integrado com AudioManager e TransicaoWipe

extends Control
class_name QuartoController

signal fechado(resultado: Dictionary)

# ─────────────────────────────────────────────
# EXPORTS — diálogo
# ─────────────────────────────────────────────

@export var dialogo_label: RichTextLabel
@export var opcoes_container: VBoxContainer
@export var botao_template: Button
@export var botao_sair: TextureButton
@export var botao_avancar: TextureButton
@export var feedback_imagem: TextureRect
@export var feedback_duracao: float = 1.8
@export var typewriter_velocidade: float = 0.03
@export var paineis_root: Control

# ─────────────────────────────────────────────
# EXPORTS — painel flutuante do quiz
# ─────────────────────────────────────────────

## O painel inteiro do quiz (invisível por padrão)
@export var quiz_painel: Control

## Label da pergunta — dentro do quiz_painel
@export var quiz_pergunta_label: RichTextLabel

## VBoxContainer das alternativas — dentro do quiz_painel
@export var quiz_opcoes_container: VBoxContainer

## Button template das alternativas — dentro do quiz_painel, invisível por padrão
@export var quiz_botao_template: Button

## O box inteiro do feedback (pai do quiz_feedback_label) — arraste aqui no Inspector
@export var quiz_feedback_box: Control

## Label de feedback dentro do quiz_feedback_box
@export var quiz_feedback_label: Label

## Duração da animação de entrada/saída em segundos
@export var quiz_feedback_anim_dur: float = 0.35

## Tempo que o feedback fica visível antes de sair
@export var quiz_feedback_tempo: float = 1.6

## Tempo que a dica fica visível no box_feedback (0 = fica até a próxima pergunta)
@export var quiz_dica_tempo: float = 0.0

## De qual lado o box_feedback entra na tela
@export_enum("esquerda", "direita") var quiz_feedback_lado: String = "esquerda"

# ─────────────────────────────────────────────
# EXPORTS — personagem flutuante
# ─────────────────────────────────────────────

## Nó PersonagemDialogo — arraste o nó aqui no Inspector
@export var personagem: PersonagemDialogo

# ─────────────────────────────────────────────
# ESTADO
# ─────────────────────────────────────────────

var _narrativa: NarrativeSystem = null
var _dialog: DialogSystem = DialogSystem.new()
var _dados_quarto: Dictionary = {}
var _resultado: Dictionary = {}
var _aguardando := false
var _escolhas_pend = null
var _digitando := false

# quiz
var _quiz_ativo     := false
var _quiz_perguntas : Array = []
var _quiz_indice    : int   = 0
var _quiz_acertos   : int   = 0
var _quiz_set_acerto: Dictionary = {}
var _quiz_set_erro  : Dictionary = {}
var _quiz_nota_min  : float = 0.5
var _quiz_ram_ok    : String = ""
var _quiz_ram_nao   : String = ""
var _quiz_respondeu := false

# feedback box
var _feedback_box_x_original: float = 0.0

# wipe
var _wipe: Node

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────

func _ready() -> void:
	_wipe = get_node("/root/TransicaoWipe")
	add_child(_dialog)
	visible = false

	if botao_sair:
		botao_sair.pressed.connect(_fechar)
	if botao_avancar:
		botao_avancar.pressed.connect(_avancar_dialogo)
		botao_avancar.modulate.a = 0.3
	if botao_template:
		botao_template.visible = false

	opcoes_container.visible = false

	if feedback_imagem:
		feedback_imagem.modulate.a = 0.0
		feedback_imagem.visible    = false
	if quiz_painel:
		quiz_painel.visible = false
	if quiz_botao_template:
		quiz_botao_template.visible = false

	# Guarda a posição X de destino e esconde fora da tela
	if quiz_feedback_box:
		quiz_feedback_box.visible = true
		_feedback_box_x_original  = quiz_feedback_box.position.x
		quiz_feedback_box.position.x = _feedback_x_fora()

	if quiz_feedback_label:
		quiz_feedback_label.visible = false

	_esconder_paineis()

# ─────────────────────────────────────────────
# ABRIR
# ─────────────────────────────────────────────

func abrir(id_quarto: String, dados_json: Dictionary, narrativa: NarrativeSystem) -> void:
	_narrativa     = narrativa
	_resultado     = {}
	_aguardando    = false
	_escolhas_pend = null
	_digitando     = false
	_quiz_ativo    = false

	var quartos: Dictionary = dados_json.get("quartos", {})
	if not quartos.has(id_quarto):
		push_error("QuartoController: quarto '%s' não encontrado." % id_quarto)
		emit_signal("fechado", {})
		return

	_dados_quarto = quartos[id_quarto]

	# ✅ RESET DE UI — garante estado limpo independente do que aconteceu no quarto anterior
	if dialogo_label:
		dialogo_label.visible = true
		dialogo_label.clear()
	if botao_avancar:
		botao_avancar.visible  = true
		botao_avancar.modulate.a = 0.3
	if botao_sair:
		botao_sair.visible = true
	if opcoes_container:
		opcoes_container.visible = false
	if quiz_painel:
		quiz_painel.visible = false
	if quiz_opcoes_container:
		quiz_opcoes_container.visible = false

	# ✅ Restaura box_complemento caso tenha sido oculto pelo quiz anterior
	if paineis_root:
		var box = paineis_root.get_node_or_null("box_complemento")
		if box:
			box.visible = true

	_esconder_paineis()
	var nome_painel: String = _dados_quarto.get("painel", "")
	if nome_painel != "" and paineis_root:
		var painel = paineis_root.get_node_or_null(nome_painel)
		if painel is Control:
			painel.visible = true
		else:
			push_error("QuartoController: painel '%s' não encontrado." % nome_painel)

	# Garante que o feedback_box está fora da tela
	if quiz_feedback_box:
		quiz_feedback_box.position.x = _feedback_x_fora()
	if quiz_feedback_label:
		quiz_feedback_label.visible = false

	_resultado["ramificacao"] = _dados_quarto.get("ramificacao_padrao", "")
	_dialog.iniciar(_dados_quarto)

	visible = true
	show()
	move_to_front()
	z_index = 999
	_processar()

# ─────────────────────────────────────────────
# PROCESSAMENTO
# ─────────────────────────────────────────────

func _processar() -> void:
	if _escolhas_pend != null:
		var lista = _escolhas_pend
		_escolhas_pend = null
		_mostrar_escolhas(lista)
		return

	while true:
		var entrada = _dialog.proximo()

		if entrada == null or entrada.has("fim"):
			if entrada != null and entrada.has("set"):
				_aplicar_e_atualizar(entrada["set"])
			_fechar()
			return

		if entrada.has("condicao"):
			if not _narrativa.checar(entrada["condicao"]):
				continue

		if entrada.has("ramificacao"):
			_resultado["ramificacao"] = entrada["ramificacao"]

		if entrada.has("set") and not entrada.has("escolhas"):
			_aplicar_e_atualizar(entrada["set"])

		if entrada.has("quiz"):
			await _quiz_iniciar(entrada)
			return

		if entrada.has("escolhas") and not entrada.has("fala"):
			_mostrar_escolhas(entrada["escolhas"])
			return

		if entrada.has("fala"):
			# ✅ PERSONAGEM: atualiza sprite/posição antes de exibir o texto
			if personagem:
				personagem.atualizar(entrada)
			await _exibir(entrada["fala"])
			if entrada.has("escolhas"):
				_escolhas_pend = entrada["escolhas"]
			_aguardando = true
			return

# ─────────────────────────────────────────────
# QUIZ — painel flutuante
# ─────────────────────────────────────────────

func _quiz_iniciar(entrada: Dictionary) -> void:
	_quiz_ativo      = true
	_quiz_perguntas  = entrada.get("quiz", [])
	_quiz_indice     = 0
	_quiz_acertos    = 0
	_quiz_set_acerto = entrada.get("set_acerto", {})
	_quiz_set_erro   = entrada.get("set_erro", {})
	_quiz_nota_min   = float(entrada.get("nota_minima", 0.5))
	_quiz_ram_ok     = entrada.get("ramificacao_aprovado", "")
	_quiz_ram_nao    = entrada.get("ramificacao_reprovado", "")

	# ✅ Oculta caixa de diálogo durante o quiz
	if dialogo_label:
		dialogo_label.visible = false
	if botao_avancar:
		botao_avancar.visible = false
	if opcoes_container:
		opcoes_container.visible = false

	# ✅ Oculta o box_complemento inteiro
	if paineis_root:
		var box = paineis_root.get_node_or_null("box_complemento")
		if box:
			box.visible = false

	if quiz_painel:
		var pai = quiz_painel.get_parent()
		while pai != null and pai != self:
			if pai is Control:
				pai.visible = true
			pai = pai.get_parent()
		quiz_painel.visible = true

	_quiz_exibir()

func _quiz_exibir() -> void:
	_quiz_respondeu = false

	var p: Dictionary = _quiz_perguntas[_quiz_indice]

	# Texto da pergunta — SEM dica embutida
	var texto_pergunta: String = "[%d/%d]  %s" % [
		_quiz_indice + 1,
		_quiz_perguntas.size(),
		p.get("pergunta", "")
	]

	if quiz_pergunta_label:
		quiz_pergunta_label.text = texto_pergunta

	# Garante que o feedback_box está fora da tela ao trocar de pergunta
	if quiz_feedback_box:
		quiz_feedback_box.position.x = _feedback_x_fora()
	if quiz_feedback_label:
		quiz_feedback_label.visible = false

	_quiz_montar_botoes(p.get("alternativas", []))

	# Exibe dica no box_feedback se o jogador cumpriu a condição
	if p.has("dica") and _narrativa:
		var dica: Dictionary = p["dica"]
		var condicao = dica.get("condicao", "")
		var cond_dict: Dictionary = {}
		if condicao is String and condicao != "":
			cond_dict[condicao] = true
		elif condicao is Dictionary:
			cond_dict = condicao
		if not cond_dict.is_empty() and _narrativa.checar(cond_dict):
			_quiz_dica_mostrar(dica.get("texto", ""))

func _quiz_montar_botoes(lista: Array) -> void:
	if not quiz_opcoes_container or not quiz_botao_template:
		return

	for filho in quiz_opcoes_container.get_children():
		if filho != quiz_botao_template:
			filho.queue_free()

	quiz_opcoes_container.visible = true

	for alt in lista:
		var btn: Button = quiz_botao_template.duplicate()
		btn.visible  = true
		btn.disabled = false
		btn.text     = alt.get("texto", "")

		var correta : bool   = alt.get("correta", false)
		var feedback: String = alt.get("feedback", "")

		btn.pressed.connect(_quiz_responder.bind(btn, correta, feedback))
		quiz_opcoes_container.add_child(btn)

func _quiz_responder(btn_clicado: Button, correta: bool, feedback: String) -> void:
	_quiz_respondeu = true

	for filho in quiz_opcoes_container.get_children():
		if filho == quiz_botao_template:
			continue
		filho.disabled = true

	_colorir(btn_clicado, Color.GREEN if correta else Color.RED)

	# ✅ ÁUDIO: toca feedback sonoro de acerto ou erro
	if correta:
		AudioManager.sfx_correct()
	else:
		AudioManager.sfx_wrong()

	if correta:
		_quiz_acertos += 1

	if _narrativa:
		if correta and not _quiz_set_acerto.is_empty():
			_narrativa.aplicar_efeitos(_quiz_set_acerto)
		elif not correta and not _quiz_set_erro.is_empty():
			_narrativa.aplicar_efeitos(_quiz_set_erro)

	# ✅ Monta texto e cor do feedback
	var texto_fb := feedback if feedback != "" else ("✓ Correto!" if correta else "✗ Errado!")
	var cor_fb   := Color.GREEN if correta else Color.BLACK

	# ✅ Se havia uma dica visível, desliza para fora antes de mostrar o feedback
	if quiz_feedback_box and quiz_feedback_box.position.x == _feedback_box_x_original:
		await _quiz_feedback_esconder()

	# ✅ Desliza box_feedback da esquerda para dentro
	await _quiz_feedback_mostrar(texto_fb, cor_fb)

	# Aguarda o tempo configurado com o feedback visível
	await get_tree().create_timer(quiz_feedback_tempo).timeout

	# ✅ Desliza box_feedback de volta para fora à esquerda
	await _quiz_feedback_esconder()

	_quiz_indice += 1
	if _quiz_indice >= _quiz_perguntas.size():
		_quiz_encerrar()
	else:
		_quiz_exibir()

func _quiz_encerrar() -> void:
	var total    := _quiz_perguntas.size()
	var prop     := float(_quiz_acertos) / float(total) if total > 0 else 0.0
	var aprovado := prop >= _quiz_nota_min
	var estrelas := "★★★" if prop >= 0.9 else ("★★☆" if prop >= 0.6 else "★☆☆")

	if quiz_pergunta_label:
		quiz_pergunta_label.text = "%s  %d de %d corretas" % [estrelas, _quiz_acertos, total]

	if quiz_opcoes_container:
		quiz_opcoes_container.visible = false

	# Garante que o feedback_box está escondido ao encerrar
	if quiz_feedback_box:
		quiz_feedback_box.position.x = _feedback_x_fora()
	if quiz_feedback_label:
		quiz_feedback_label.visible = false

	if aprovado and _quiz_ram_ok != "":
		_resultado["ramificacao"] = _quiz_ram_ok
	elif not aprovado and _quiz_ram_nao != "":
		_resultado["ramificacao"] = _quiz_ram_nao

	await get_tree().create_timer(2.0).timeout

	if quiz_painel:
		quiz_painel.visible = false

	# ✅ Restaura caixa de diálogo ao encerrar o quiz
	if dialogo_label:
		dialogo_label.visible = true
	if botao_avancar:
		botao_avancar.visible = true
	if opcoes_container:
		opcoes_container.visible = true

	# ✅ Restaura o painel de complementos (box_complemento) oculto durante o quiz
	if paineis_root:
		var box = paineis_root.get_node_or_null("box_complemento")
		if box:
			box.visible = true

	_quiz_ativo = false
	_processar()

func _colorir(btn: Button, cor: Color) -> void:
	btn.add_theme_color_override("font_color",         cor)
	btn.add_theme_color_override("font_pressed_color", cor)
	btn.add_theme_color_override("font_hover_color",   cor)

# ─────────────────────────────────────────────
# QUIZ — animação do box_feedback
# ─────────────────────────────────────────────

## Retorna o position.x local que coloca o box completamente fora da tela.
## Usa quiz_feedback_lado para determinar se sai pela esquerda ou direita.
func _feedback_x_fora() -> float:
	if not quiz_feedback_box:
		return 0.0
	if quiz_feedback_lado == "direita":
		# Coloca o lado esquerdo do box além da borda direita da viewport
		var viewport_w := get_viewport_rect().size.x
		return quiz_feedback_box.position.x + (viewport_w - quiz_feedback_box.global_position.x)
	else:
		# Padrão: sai pela esquerda (lado direito do box em x=0)
		return quiz_feedback_box.position.x - (quiz_feedback_box.global_position.x + quiz_feedback_box.size.x)


func _quiz_dica_mostrar(texto: String) -> void:
	if not quiz_feedback_box or texto == "":
		return

	if quiz_feedback_label:
		quiz_feedback_label.text = texto
		quiz_feedback_label.add_theme_color_override("font_color", Color.BLACK)
		quiz_feedback_label.visible = true

	# Posiciona fora da tela e desliza para dentro
	quiz_feedback_box.position.x = _feedback_x_fora()
	var tw_in := create_tween()
	tw_in.tween_property(
		quiz_feedback_box, "position:x",
		_feedback_box_x_original,
		quiz_feedback_anim_dur
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	# Se quiz_dica_tempo > 0 esconde automaticamente; senão fica até o próximo feedback
	if quiz_dica_tempo > 0.0:
		await get_tree().create_timer(quiz_dica_tempo).timeout
		await _quiz_feedback_esconder()


func _quiz_feedback_mostrar(texto: String, cor: Color) -> void:
	if not quiz_feedback_box:
		return

	# Atualiza o label interno
	if quiz_feedback_label:
		quiz_feedback_label.text = texto
		quiz_feedback_label.add_theme_color_override("font_color", cor)
		quiz_feedback_label.visible = true

	# Coloca fora da tela à esquerda (cálculo global, independe do pai)
	quiz_feedback_box.position.x = _feedback_x_fora()

	# Desliza para a posição original (visível)
	var tw_in := create_tween()
	tw_in.tween_property(
		quiz_feedback_box, "position:x",
		_feedback_box_x_original,
		quiz_feedback_anim_dur
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw_in.finished


func _quiz_feedback_esconder() -> void:
	if not quiz_feedback_box:
		return

	# Desliza para fora à esquerda (cálculo global)
	var tw_out := create_tween()
	tw_out.tween_property(
		quiz_feedback_box, "position:x",
		_feedback_x_fora(),
		quiz_feedback_anim_dur
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw_out.finished

	if quiz_feedback_label:
		quiz_feedback_label.visible = false

# ─────────────────────────────────────────────
# TYPEWRITER
# ─────────────────────────────────────────────

func _exibir(texto: String) -> void:
	_digitando = true
	if botao_avancar:
		botao_avancar.modulate.a = 0.3

	dialogo_label.clear()
	dialogo_label.text = texto
	dialogo_label.visible_characters = 0

	var total := texto.length()
	var tw = create_tween()
	tw.tween_method(
		func(v: int): dialogo_label.visible_characters = v,
		0, total, total * typewriter_velocidade
	)
	await tw.finished

	dialogo_label.visible_characters = -1
	_digitando = false
	if botao_avancar:
		botao_avancar.modulate.a = 1.0

# ─────────────────────────────────────────────
# AVANÇAR
# ─────────────────────────────────────────────

func _avancar_dialogo() -> void:
	if not visible or not _aguardando or _quiz_ativo:
		return
	if opcoes_container.visible:
		return
	if _digitando:
		dialogo_label.visible_characters = -1
		_digitando = false
		if botao_avancar:
			botao_avancar.modulate.a = 1.0
		return
	_aguardando = false
	if botao_avancar:
		botao_avancar.modulate.a = 0.3

	# ✅ ÁUDIO: som ao avançar fala
	AudioManager.sfx_dialog()

	_processar()

# ─────────────────────────────────────────────
# ESCOLHAS
# ─────────────────────────────────────────────

func _mostrar_escolhas(lista: Array) -> void:
	if not is_instance_valid(botao_template):
		push_error("QuartoController: botao_template inválido.")
		return

	opcoes_container.visible = true

	for filho in opcoes_container.get_children():
		if filho != botao_template:
			filho.queue_free()

	for escolha in lista:
		if escolha.has("condicao"):
			if not _narrativa.checar(escolha["condicao"]):
				continue

		var btn: Button = botao_template.duplicate()
		btn.visible  = true
		btn.disabled = false
		btn.text     = escolha.get("texto", "...")

		var e = escolha
		btn.pressed.connect(func():
			# ✅ ÁUDIO: som ao selecionar uma escolha
			AudioManager.sfx_click()
			opcoes_container.visible = false
			if e.has("set"):
				_aplicar_e_atualizar(e["set"])
			if e.has("ramificacao"):
				_resultado["ramificacao"] = e["ramificacao"]
			if e.has("proximo"):
				_dialog.pular_para(e["proximo"])
			if e.has("imagem_feedback") and feedback_imagem:
				await _mostrar_feedback(e["imagem_feedback"])
			_processar()
		)
		opcoes_container.add_child(btn)

# ─────────────────────────────────────────────
# INPUT
# ─────────────────────────────────────────────

func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not _aguardando or _quiz_ativo:
		return
	if opcoes_container.visible:
		return
	if evento.is_action_pressed("ui_accept") or (
		evento is InputEventMouseButton
		and evento.button_index == MOUSE_BUTTON_LEFT
		and evento.pressed
	):
		if _digitando:
			dialogo_label.visible_characters = -1
			_digitando = false
			get_viewport().set_input_as_handled()
			return
		_aguardando = false
		get_viewport().set_input_as_handled()

		# ✅ ÁUDIO: som ao avançar fala via teclado/clique
		AudioManager.sfx_dialog()

		_processar()

# ─────────────────────────────────────────────
# UTILITÁRIOS
# ─────────────────────────────────────────────

func _aplicar_e_atualizar(efeitos: Dictionary) -> void:
	if _narrativa:
		_narrativa.aplicar_efeitos(efeitos)

func _esconder_paineis() -> void:
	if not paineis_root:
		return
	for painel in paineis_root.get_children():
		if painel.name == "box_complemento":
			continue
		if painel is Control:
			painel.visible = false

func _mostrar_feedback(caminho_imagem: String) -> void:
	if not feedback_imagem:
		return
	var tex = load(caminho_imagem)
	if tex == null:
		push_error("QuartoController: feedback não encontrado: '%s'" % caminho_imagem)
		return
	feedback_imagem.texture    = tex
	feedback_imagem.visible    = true
	feedback_imagem.modulate.a = 0.0

	var tw_in = create_tween()
	tw_in.tween_property(feedback_imagem, "modulate:a", 1.0, 0.25)
	await tw_in.finished
	await get_tree().create_timer(feedback_duracao).timeout
	var tw_out = create_tween()
	tw_out.tween_property(feedback_imagem, "modulate:a", 0.0, 0.35)
	await tw_out.finished
	feedback_imagem.visible = false

# ─────────────────────────────────────────────
# FECHAR (com wipe)
# ─────────────────────────────────────────────

func _fechar() -> void:
	await _wipe.fechar()

	visible = false

	if personagem:
		personagem.atualizar({"personagem_ocultar": true})

	opcoes_container.visible = false
	_aguardando = false
	_digitando  = false
	_quiz_ativo = false
	dialogo_label.clear()

	if feedback_imagem:
		feedback_imagem.visible = false
	if quiz_painel:
		quiz_painel.visible = false

	# Garante que o feedback_box volta para fora da tela ao fechar
	if quiz_feedback_box:
		quiz_feedback_box.position.x = _feedback_x_fora()
	if quiz_feedback_label:
		quiz_feedback_label.visible = false

	_esconder_paineis()

	await get_tree().process_frame
	await get_tree().process_frame
	await _wipe.abrir()

	emit_signal("fechado", _resultado)
