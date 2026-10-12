extends Node


var nome_jogador: String = ""
var id_narrativa_atual: String = ""
var historias_jogadas: Array[String] = []

func definir_nome(nome: String) -> void:
	nome_jogador = nome.strip_edges()
	print("PlayerData: Nome definido como '%s'" % nome_jogador)

func definir_narrativa_atual(id_narrativa: String) -> void:
	id_narrativa_atual = id_narrativa
	print("PlayerData: Narrativa atual: '%s'" % id_narrativa)

func pode_jogar_historia(id_historia: String) -> bool:
	return id_historia not in historias_jogadas

func registrar_historia_jogada(id_historia: String) -> void:
	if id_historia not in historias_jogadas:
		historias_jogadas.append(id_historia)
		print("PlayerData: História '%s' registrada como jogada" % id_historia)

func resetar() -> void:
	nome_jogador = ""
	id_narrativa_atual = ""
	historias_jogadas = []
	print("PlayerData: Dados resetados")
