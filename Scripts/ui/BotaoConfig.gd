extends Resource
class_name BotaoConfig

enum Acao {
	TROCAR_PAINEL,
	TROCAR_CENA,
	SAIR
}

@export var botao_path: NodePath
@export var acao: Acao

@export var id_painel: int = 0
@export var caminho_cena: String = ""
