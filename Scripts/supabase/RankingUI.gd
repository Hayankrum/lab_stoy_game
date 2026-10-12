extends Control
class_name RankingUI

@export var container_principal: VBoxContainer
@export var loading_label: Label
@export var botao_atualizar: Button

var _carregando := false
var _narrativas = ["caminho_para_prova", "um_mundo_sem_som"]
var _containers_ranking: Dictionary = {}
var _timer_auto: Timer

# ─── Ready ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if botao_atualizar:
		botao_atualizar.pressed.connect(_atualizar_ranking)

	if loading_label:
		loading_label.visible = false

	_criar_interface_vertical()
	_atualizar_ranking()

	# Timer de auto-atualização a cada 5 segundos
	_timer_auto = Timer.new()
	_timer_auto.wait_time = 5.0
	_timer_auto.autostart = true
	_timer_auto.timeout.connect(_atualizar_ranking)
	add_child(_timer_auto)

# ─── Criar Interface Vertical (uma tabela abaixo da outra) ─────────────────────

func _criar_interface_vertical() -> void:
	if not container_principal:
		return

	for narrativa_id in _narrativas:
		# Espaçador visual entre tabelas (exceto antes da primeira)
		if _containers_ranking.size() > 0:
			var separador = HSeparator.new()
			separador.add_theme_constant_override("separation", 16)
			container_principal.add_child(separador)

		# Título da narrativa
		var titulo = Label.new()
		titulo.text = _traduzir_narrativa(narrativa_id)
		titulo.add_theme_font_size_override("font_size", 18)
		titulo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		container_principal.add_child(titulo)

		# Container da lista
		var lista = VBoxContainer.new()
		lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lista.add_theme_constant_override("separation", 5)
		container_principal.add_child(lista)

		_containers_ranking[narrativa_id] = lista

# ─── Atualizar Ranking ─────────────────────────────────────────────────────────

func _atualizar_ranking() -> void:
	if _carregando:
		return

	_carregando = true

	if loading_label:
		loading_label.visible = true

	var dados_prova = await ranking_manager.carregar_ranking(0, "caminho_para_prova")
	var dados_som   = await ranking_manager.carregar_ranking(0, "um_mundo_sem_som")

	_carregando = false

	if loading_label:
		loading_label.visible = false

	_preencher_lista("caminho_para_prova", dados_prova)
	_preencher_lista("um_mundo_sem_som", dados_som)

func _traduzir_narrativa(id: String) -> String:
	match id:
		"caminho_para_prova": return "🎓 Caminho para a Prova"
		"um_mundo_sem_som":   return "🔇 Um Mundo Sem Som"
		_:                    return "Ranking Geral"

# ─── Preencher Lista ───────────────────────────────────────────────────────────

func _preencher_lista(narrativa_id: String, dados: Array) -> void:
	if narrativa_id not in _containers_ranking:
		return

	var lista_container = _containers_ranking[narrativa_id]

	for filho in lista_container.get_children():
		filho.queue_free()

	if dados.is_empty():
		var label = Label.new()
		label.text = "Nenhum jogador ainda."
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lista_container.add_child(label)
		return

	_adicionar_linha_cabecalho(lista_container, dados.size())

	for indice in range(dados.size()):
		_adicionar_item_ranking(lista_container, indice + 1, dados[indice])

# ─── Cabeçalho ─────────────────────────────────────────────────────────────────

func _adicionar_linha_cabecalho(container: VBoxContainer, total: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)

	var lp = Label.new()
	lp.text = "Pos"
	lp.custom_minimum_size.x = 35
	lp.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hbox.add_child(lp)

	var ln = Label.new()
	ln.text = "Jogador (%d)" % total
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ln.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hbox.add_child(ln)

	var lpt = Label.new()
	lpt.text = "Pts"
	lpt.custom_minimum_size.x = 55
	lpt.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hbox.add_child(lpt)

	var lac = Label.new()
	lac.text = "✅ Ac"
	lac.custom_minimum_size.x = 45
	lac.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hbox.add_child(lac)

	var ler = Label.new()
	ler.text = "❌ Er"
	ler.custom_minimum_size.x = 45
	ler.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hbox.add_child(ler)

	var lr = Label.new()
	lr.text = "Resultado"
	lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hbox.add_child(lr)

	container.add_child(hbox)

# ─── Item do Ranking ───────────────────────────────────────────────────────────

func _adicionar_item_ranking(container: VBoxContainer, posicao: int, item: Dictionary) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)

	var label_pos = Label.new()
	if posicao == 1:   label_pos.text = "🥇"
	elif posicao == 2: label_pos.text = "🥈"
	elif posicao == 3: label_pos.text = "🥉"
	else:              label_pos.text = str(posicao)
	label_pos.custom_minimum_size.x = 35
	label_pos.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hbox.add_child(label_pos)

	var label_nome = Label.new()
	label_nome.text = item.get("nome", "???")
	label_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_nome.add_theme_color_override("font_color", _cor_posicao(posicao))
	label_nome.clip_text = true
	hbox.add_child(label_nome)

	var label_pontos = Label.new()
	label_pontos.text = str(item.get("pontuacao", 0))
	label_pontos.custom_minimum_size.x = 55
	label_pontos.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	hbox.add_child(label_pontos)

	var stats: Dictionary = item.get("stats", {})

	var label_ac = Label.new()
	label_ac.text = str(stats.get("acertos", "-"))
	label_ac.custom_minimum_size.x = 45
	label_ac.add_theme_color_override("font_color", Color(0.1, 0.75, 0.2))
	hbox.add_child(label_ac)

	var label_er = Label.new()
	label_er.text = str(stats.get("erros", "-"))
	label_er.custom_minimum_size.x = 45
	label_er.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	hbox.add_child(label_er)

	var label_resultado = Label.new()
	label_resultado.text = item.get("resultado_id", "neutro").to_upper().replace("_", " ")
	label_resultado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_resultado.add_theme_color_override("font_color", Color(0.6, 0.6, 0.9))
	hbox.add_child(label_resultado)

	container.add_child(hbox)

# ─── Helpers ───────────────────────────────────────────────────────────────────

func _cor_posicao(posicao: int) -> Color:
	if posicao == 1:   return Color(1.0, 0.84, 0.0)
	elif posicao == 2: return Color(0.75, 0.75, 0.75)
	elif posicao == 3: return Color(0.8, 0.5, 0.2)
	else:              return Color(0.9, 0.9, 0.9)
