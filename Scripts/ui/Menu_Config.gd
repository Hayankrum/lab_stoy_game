# Menu_Config.gd
# GerenciadorDeBotoes com efeitos sonoros integrados ao AudioManager
extends Node

@export var container_paineis: Node
@export var configuracoes: Array[BotaoConfig]

# Intensidade do brilho ao passar o mouse
@export_range(1.0, 2.0, 0.05) var brilho_hover: float = 1.4

# Controle interno para evitar conexões duplicadas
var _botoes_configurados: Array[BaseButton] = []

# Painel atualmente aberto (-1 = nenhum)
var painel_atual := -1


func _ready() -> void:

	# Conecta automaticamente TODOS os botões da cena
	_conectar_botoes_recursivamente(get_tree().current_scene)

	# Conecta também os botões configurados no Inspector
	for config in configuracoes:
		var botao = get_node_or_null(config.botao_path)

		if botao and botao is BaseButton:
			if not botao.pressed.is_connected(_on_botao_pressed.bind(config)):
				botao.pressed.connect(_on_botao_pressed.bind(config))

	# Inicia todos os painéis fechados
	if container_paineis:
		for painel in container_paineis.get_children():
			if painel is CanvasItem:
				painel.visible = false


# ──────────────────────────────────────────────────────────────────────────────
# Varredura recursiva de botões
# ──────────────────────────────────────────────────────────────────────────────

func _conectar_botoes_recursivamente(node: Node) -> void:
	for filho in node.get_children():

		if filho is BaseButton:
			_configurar_botao(filho)

		_conectar_botoes_recursivamente(filho)


# Aplica configuração padrão (visual + som) a um botão
func _configurar_botao(botao: BaseButton) -> void:

	if botao in _botoes_configurados:
		return

	_botoes_configurados.append(botao)

	# Garante que o botão capture o mouse
	if botao is Control:
		botao.mouse_filter = Control.MOUSE_FILTER_STOP

	# Cor inicial normal
	if botao is CanvasItem:
		botao.modulate = Color.WHITE

	# Efeito de hover (visual)
	if not botao.mouse_entered.is_connected(_on_mouse_entered.bind(botao)):
		botao.mouse_entered.connect(_on_mouse_entered.bind(botao))

	if not botao.mouse_exited.is_connected(_on_mouse_exited.bind(botao)):
		botao.mouse_exited.connect(_on_mouse_exited.bind(botao))

	# ✅ Som ao clicar — conecta sem substituir conexões do Inspector
	if not botao.pressed.is_connected(_on_botao_som):
		botao.pressed.connect(_on_botao_som)


# ──────────────────────────────────────────────────────────────────────────────
# Efeitos visuais de hover
# ──────────────────────────────────────────────────────────────────────────────

func _on_mouse_entered(botao: BaseButton) -> void:
	if botao and botao is CanvasItem:
		botao.modulate = Color(brilho_hover, brilho_hover, brilho_hover)

	# ✅ Som suave de hover (sfx_dialog = dois tons suaves, discreto para menus)
	AudioManager.sfx_dialog()


func _on_mouse_exited(botao: BaseButton) -> void:
	if botao and botao is CanvasItem:
		botao.modulate = Color.WHITE


# ──────────────────────────────────────────────────────────────────────────────
# Efeito sonoro de clique (compartilhado por todos os botões)
# ──────────────────────────────────────────────────────────────────────────────

func _on_botao_som() -> void:
	AudioManager.sfx_click()


# ──────────────────────────────────────────────────────────────────────────────
# Ações dos botões configurados no Inspector
# ──────────────────────────────────────────────────────────────────────────────

func _on_botao_pressed(config: BotaoConfig) -> void:

	# O som já foi disparado por _on_botao_som antes desta chamada
	match config.acao:
		BotaoConfig.Acao.TROCAR_PAINEL:
			trocar_painel(config.id_painel)

		BotaoConfig.Acao.TROCAR_CENA:
			trocar_cena(config.caminho_cena)

		BotaoConfig.Acao.SAIR:
			sair()


# Mostra apenas o painel selecionado.
# Se clicar novamente no mesmo botão, fecha o painel.
func trocar_painel(id: int) -> void:

	if not container_paineis:
		return

	var lista = container_paineis.get_children()

	# Clicou no mesmo botão: fecha
	if painel_atual == id:
		for painel in lista:
			if painel is CanvasItem:
				painel.visible = false

		painel_atual = -1
		return

	# Abre apenas o painel selecionado
	for i in range(lista.size()):
		if lista[i] is CanvasItem:
			lista[i].visible = (i == id)

	painel_atual = id

	# ✅ Som de abertura de painel
	AudioManager.sfx_open()


# Troca de cena
func trocar_cena(caminho: String) -> void:
	if caminho.is_empty():
		return
	await _fazer_wipe_e_trocar(caminho)

func _fazer_wipe_e_trocar(caminho: String) -> void:
	var wipe = get_node_or_null("/root/TransicaoWipe")

	if wipe == null:
		get_tree().change_scene_to_file(caminho)
		return

	await wipe.fechar()
	get_tree().change_scene_to_file(caminho)
	# ✅ Não precisa mais chamar abrir() — o TransicaoWipe faz isso sozinho

# Fecha o jogo
func sair() -> void:
	get_tree().quit()
