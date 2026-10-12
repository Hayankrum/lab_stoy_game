## TelaFinal.gd
## Tela de encerramento dedicada exibida após o zoom dos blocos espaciais.

extends Control
class_name TelaFinal

# ─── Exports — UI ─────────────────────────────────────────────────────────────

@export var label_titulo:       Label
@export var label_mensagem:     RichTextLabel
@export var grade_estatisticas: GridContainer
@export var lista_decisoes:     VBoxContainer

## Label que mostra "👤 Nome  •  🏆 XYZ pts" — sempre visível, sem precisar de internet.
@export var label_jogador:      Label

# ─── Exports — navegação ──────────────────────────────────────────────────────

## Arraste o TextureButton de "menu_retorno" aqui no Inspector.
@export var botao_proxima_cena: TextureButton

## Caminho da cena de destino (ex: "res://Cenas/TelaInicial.tscn")
@export_file("*.tscn") var proxima_cena: String

# ─── Exports — ranking ────────────────────────────────────────────────────────

@export var botao_salvar_ranking: Button

# ─── Exports — config ─────────────────────────────────────────────────────────

@export var duracao_entrada:       float = 0.6
@export var velocidade_typewriter: float = 0.025

# ─── Mapeamento de estatísticas ───────────────────────────────────────────────

const NOMES_ESTAT: Dictionary = {
	# inclusao.json
	"moral":   "⚖  Moral",
	"empatia": "💛 Empatia",
	# domingo_anoite.json
	"energia": "⚡ Energia",
	"lazer":   "🎮 Lazer",
	# compartilhados
	"dicas":   "📚 Estudo",
	"social":  "💬 Social",
	"acertos": "✅ Acertos no Quiz",
	"erros":   "❌ Erros no Quiz"
}

# ─── Mapeamento de flags → decisões legíveis ──────────────────────────────────

const NOMES_FLAGS: Dictionary = {
	# inclusao.json
	"flag:apresentou":          "🤝 Apresentou Vito aos colegas",
	"flag:ensinou_sinal":       "🤟 Ensinou um sinal de Libras",
	"flag:respeitou_autonomia": "✊ Respeitou a autonomia de Vito",
	"flag:confiou":             "🌱 Confiou que os colegas conseguiriam",
	"flag:refletiu":            "💭 Refletiu sobre inclusão",
	"flag:inclusao":            "🌟 Promoveu inclusão de verdade",
	# domingo_anoite.json
	"flag:estudou_manha":       "📖 Estudou de manhã",
	"flag:dormiu":              "😴 Dormiu cedo antes da prova"
}

# ─── Estado interno ───────────────────────────────────────────────────────────

var _digitando := false
var _wipe: Node
var _resultado_final: Dictionary
var _narrativa_ref: NarrativeSystem
var _ranking_system: Node

# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	visible    = false
	modulate.a = 0.0
	_wipe      = get_node_or_null("/root/TransicaoWipe")
	_ranking_system = ranking_manager  # Use o AutoLoad global

	if botao_proxima_cena:
		botao_proxima_cena.visible    = false
		botao_proxima_cena.modulate.a = 0.0
		botao_proxima_cena.pressed.connect(_ir_para_proxima_cena)

	if botao_salvar_ranking:
		botao_salvar_ranking.visible = false
		botao_salvar_ranking.pressed.connect(_salvar_e_prosseguir)

# ─── API principal ────────────────────────────────────────────────────────────

func mostrar(resultado_final: Dictionary, narrativa: NarrativeSystem) -> void:
	print(">>> TelaFinal.mostrar() iniciado")

	_resultado_final = resultado_final
	_narrativa_ref = narrativa

	# Preenche tudo de forma síncrona (sem await)
	_preencher_titulo(resultado_final)
	_preencher_cabecalho_jogador(narrativa)  # Nome + pontuação local (funciona offline)
	_preencher_estatisticas(narrativa.estado)
	_preencher_decisoes(narrativa.flags)

	print(">>> TelaFinal: preenchimento concluído, iniciando fade")

	# Fade de entrada
	visible    = true
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, duracao_entrada) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	print(">>> TelaFinal: fade concluído, iniciando typewriter")

	# Typewriter na mensagem
	await _typewriter(resultado_final.get("texto", "FIM"))

	print(">>> TelaFinal: typewriter concluído, mostrando botão")

	# Mostra o botão para salvar no ranking
	_mostrar_formulario_ranking()

# ─── Preenchimento (tudo síncrono, sem await) ─────────────────────────────────

func _preencher_titulo(resultado: Dictionary) -> void:
	if not label_titulo:
		return
	var texto: String  = resultado.get("texto", "FIM")
	var primeira_linha := texto.split("\n")[0].strip_edges()
	var id: String     = resultado.get("id", "neutro")
	label_titulo.text  = primeira_linha if primeira_linha != "" \
						 else id.to_upper().replace("_", " ")


## Exibe nome do jogador e pontuação calculada localmente.
## Não depende de internet — funciona sempre, mesmo sem Supabase.
func _preencher_cabecalho_jogador(narrativa: NarrativeSystem) -> void:
	if not label_jogador:
		return

	var nome = PlayerData.nome_jogador
	if nome.strip_edges() == "":
		nome = "Jogador"

	# Cálculo local — mesma fórmula do RankingSystem, sem chamada de rede
	var pontuacao = ranking_manager.calcular_pontuacao(narrativa.estado, narrativa.flags)

	label_jogador.text = "👤 %s   •   🏆 %d pts" % [nome, pontuacao]
	label_jogador.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	label_jogador.add_theme_font_size_override("font_size", 20)


func _preencher_estatisticas(estado: Dictionary) -> void:
	if not grade_estatisticas:
		return

	# Remove filhos antigos sem await
	for filho in grade_estatisticas.get_children():
		filho.queue_free()

	for chave in NOMES_ESTAT.keys():
		if not estado.has(chave):
			continue
		var valor: int = int(estado[chave])

		var nome_label := Label.new()
		nome_label.text = NOMES_ESTAT[chave]
		nome_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		grade_estatisticas.add_child(nome_label)

		var valor_label := Label.new()
		valor_label.text = _barra_visual(valor) + "  %d" % valor
		valor_label.add_theme_color_override("font_color", _cor_para_valor(chave, valor))
		grade_estatisticas.add_child(valor_label)


func _preencher_decisoes(flags: Dictionary) -> void:
	if not lista_decisoes:
		return

	# Remove filhos antigos sem await
	for filho in lista_decisoes.get_children():
		filho.queue_free()

	var alguma := false

	for flag_chave in NOMES_FLAGS.keys():
		if flags.get(flag_chave, false) == true:
			alguma = true
			var l := Label.new()
			l.text = NOMES_FLAGS[flag_chave]
			l.add_theme_color_override("font_color", Color(0.1, 0.55, 0.2))
			lista_decisoes.add_child(l)

	for flag_chave in NOMES_FLAGS.keys():
		if flags.has(flag_chave) and flags[flag_chave] == false:
			var l := Label.new()
			l.text = "✗  Não " + NOMES_FLAGS[flag_chave].substr(3).to_lower()
			l.add_theme_color_override("font_color", Color(0.75, 0.1, 0.1))
			lista_decisoes.add_child(l)

	if not alguma:
		var l := Label.new()
		l.text = "(nenhuma decisão registrada)"
		l.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		lista_decisoes.add_child(l)

# ─── Typewriter ───────────────────────────────────────────────────────────────

func _typewriter(texto: String) -> void:
	if not label_mensagem:
		# Sem label_mensagem, só aguarda um instante e segue
		await get_tree().create_timer(0.1).timeout
		return

	_digitando = true
	label_mensagem.clear()

	# Remove a primeira linha (já está no título)
	var linhas := texto.split("\n")
	var corpo  := "\n".join(linhas.slice(1)).strip_edges()

	label_mensagem.text               = corpo
	label_mensagem.visible_characters = 0

	var total := corpo.length()
	if total == 0:
		_digitando = false
		return

	var tw = create_tween()
	tw.tween_method(
		func(v: int): label_mensagem.visible_characters = v,
		0, total, total * velocidade_typewriter
	)
	await tw.finished

	label_mensagem.visible_characters = -1
	_digitando = false


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not _digitando:
		return
	if evento.is_action_pressed("ui_accept") or (
		evento is InputEventMouseButton
		and evento.button_index == MOUSE_BUTTON_LEFT
		and evento.pressed
	):
		_digitando = false
		if label_mensagem:
			label_mensagem.visible_characters = -1
		get_viewport().set_input_as_handled()

# ─── Botão proxima cena ───────────────────────────────────────────────────────

func _ir_para_proxima_cena() -> void:
	if proxima_cena.is_empty():
		push_error("TelaFinal: proxima_cena não definida no Inspector.")
		return

	if _wipe:
		await _wipe.fechar()

	get_tree().change_scene_to_file(proxima_cena)

# ─── Ranking (salvar no Supabase) ──────────────────────────────────────────────

func _mostrar_formulario_ranking() -> void:
	if botao_salvar_ranking:
		botao_salvar_ranking.visible = true
		botao_salvar_ranking.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(botao_salvar_ranking, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _salvar_e_prosseguir() -> void:
	# Desabilita o botão imediatamente para evitar clique duplo
	if botao_salvar_ranking:
		botao_salvar_ranking.disabled = true
		botao_salvar_ranking.text = "Salvando... ⏳"

	# Se não há ranking system, vai direto
	if not _ranking_system:
		await _ir_para_proxima_cena()
		return

	var nome = PlayerData.nome_jogador
	if nome.strip_edges() == "":
		push_warning("TelaFinal: Nome não definido, pulando salvamento.")
		await _ir_para_proxima_cena()
		return

	print("TelaFinal: Tentando salvar resultado para '%s'..." % nome)

	# Tenta salvar — o SupabaseManager tem timeout embutido de 8s,
	# então isso SEMPRE termina, com ou sem internet.
	var sucesso = await ranking_manager.salvar_resultado(nome, _resultado_final, _narrativa_ref)

	if sucesso:
		print("TelaFinal: Salvo com sucesso!")
		if botao_salvar_ranking:
			botao_salvar_ranking.text = "Salvo! ✅"
	else:
		push_warning("TelaFinal: Falha ao salvar (offline?). Seguindo mesmo assim.")
		if botao_salvar_ranking:
			botao_salvar_ranking.text = "Sem conexão ⚠️"

	# Pequena pausa para o jogador ver o feedback, depois segue
	await get_tree().create_timer(1.0).timeout
	await _ir_para_proxima_cena()


# ─── Helpers visuais ──────────────────────────────────────────────────────────

func _barra_visual(valor: int) -> String:
	var blocos := clampi(valor, 0, 6)
	return "█".repeat(blocos) + "░".repeat(6 - blocos)


func _cor_para_valor(chave: String, valor: int) -> Color:
	match chave:
		"dicas":   return Color(0.0, 0.55, 0.75)
		"acertos": return Color(0.1, 0.55, 0.2)
		"erros":   return Color(0.75, 0.1, 0.1)
		"lazer":   return Color(0.7, 0.5, 0.0)
		"energia": return Color(0.1, 0.6, 0.3)
		_:
			if valor > 3:   return Color(0.1, 0.55, 0.2)
			elif valor > 0: return Color(0.2, 0.2, 0.2)
			else:           return Color(0.5, 0.5, 0.5)
