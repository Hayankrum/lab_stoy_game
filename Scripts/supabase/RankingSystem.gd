extends Node
class_name RankingSystem

signal dados_salvos

var _supabase: SupabaseManager

# ─── Ready ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_supabase = SupabaseManager.new()
	add_child(_supabase)

# ─── API: Calcular pontuação ───────────────────────────────────────────────────

func calcular_pontuacao(estado: Dictionary, flags: Dictionary) -> int:
	var pontos = 0

	# Stats diretas (peso por importância)
	pontos += estado.get("moral", 0) * 10
	pontos += estado.get("empatia", 0) * 10
	pontos += estado.get("coragem", 0) * 10
	pontos += estado.get("dicas", 0) * 5
	pontos += estado.get("energia", 0) * 5
	pontos += estado.get("lazer", 0) * 5
	pontos += estado.get("social", 0) * 8

	# Quiz
	pontos += estado.get("acertos", 0) * 15
	pontos -= estado.get("erros", 0) * 5

	# Bonus por flags importantes
	var bonus_flags = 0
	for chave: String in flags:
		if flags[chave] == true:
			bonus_flags += 50

	pontos += bonus_flags

	return max(0, pontos)  # Mínimo 0

# ─── API: Salvar resultado ─────────────────────────────────────────────────────

func salvar_resultado(nome_jogador: String, resultado_final: Dictionary,
					  narrativa: NarrativeSystem) -> void:
	print("RankingSystem: Salvando resultado para '%s'" % nome_jogador)

	# Validações
	if nome_jogador.strip_edges() == "":
		push_error("RankingSystem: Nome de jogador vazio!")
		return

	# Coleta dados
	var pontuacao = calcular_pontuacao(narrativa.estado, narrativa.flags)
	var resultado_id = resultado_final.get("id", "neutro")
	var id_narrativa = PlayerData.id_narrativa_atual

	print("  Nome: %s" % nome_jogador)
	print("  Pontuação: %d" % pontuacao)
	print("  Resultado: %s" % resultado_id)
	print("  Narrativa: %s" % id_narrativa)

	# Salva no Supabase
	var sucesso = await _supabase.salvar_resultado(
		nome_jogador,
		pontuacao,
		resultado_id,
		narrativa.estado,
		narrativa.flags,
		id_narrativa
	)

	if sucesso:
		emit_signal("dados_salvos")
	else:
		push_error("RankingSystem: Falha ao salvar dados!")

# ─── API: Carregar ranking ─────────────────────────────────────────────────────

func carregar_ranking(limite: int = 10, id_narrativa: String = "") -> Array:
	print("RankingSystem: Carregando top %d para narrativa '%s'" % [limite, id_narrativa])
	return await _supabase.carregar_ranking(limite, id_narrativa)
