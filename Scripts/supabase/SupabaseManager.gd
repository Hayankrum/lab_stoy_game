extends Node
class_name SupabaseManager

# ⚙️ CONFIGURAÇÃO — Preencha com seus dados do Supabase
const SUPABASE_URL     = "https://vaogtjxrbchwonlrqfma.supabase.co"
const SUPABASE_ANONKEY = "sb_publishable_8eaWgYBdFMoTBHRTNT2R1w_PtQQDYO-"

# Tempo máximo de espera por qualquer requisição (segundos).
# Se o Supabase não responder nesse tempo, desiste e segue o jogo.
const TIMEOUT_SEGUNDOS = 8.0

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Faz a requisição com timeout. Se demorar mais que TIMEOUT_SEGUNDOS,
# cancela e retorna erro — o jogo nunca fica preso esperando.
func _fazer_request(url: String, headers: Array, method: int = HTTPClient.METHOD_GET, body: String = "") -> Array:
	var http = HTTPRequest.new()
	add_child(http)

	var error: int
	if body != "":
		error = http.request(url, headers, method, body)
	else:
		error = http.request(url, headers, method)

	if error != OK:
		http.queue_free()
		push_warning("SupabaseManager: Erro ao iniciar requisição (%d)" % error)
		return [-1, error, [], PackedByteArray()]

	# Usa Array como container mutável — workaround para o bug de lambda
	# capture do GDScript 4 (variáveis primitivas capturadas não são modificáveis).
	# estado[0] = bool concluido | resposta[0..3] = dados da rede
	var estado   = [false]
	var resposta = [[-1, 0, [], PackedByteArray()]]

	http.request_completed.connect(func(result, code, hdrs, body_bytes):
		estado[0]   = true
		resposta[0] = [result, code, hdrs, body_bytes]
	, CONNECT_ONE_SHOT)

	# Aguarda até o timeout — verifica a cada frame se já chegou resposta
	var tempo = 0.0
	while not estado[0] and tempo < TIMEOUT_SEGUNDOS:
		await get_tree().process_frame
		tempo += get_process_delta_time()

	if not estado[0]:
		push_warning("SupabaseManager: Timeout após %.1fs — sem resposta do servidor." % TIMEOUT_SEGUNDOS)
		http.cancel_request()

	http.queue_free()
	return resposta[0]

# ─── API: Salvar pontuação ─────────────────────────────────────────────────────

func salvar_resultado(nome_jogador: String, pontuacao: int, resultado_id: String,
					  stats: Dictionary, flags: Dictionary, id_narrativa: String = "") -> bool:
	print("SupabaseManager: Salvando resultado para '%s'" % nome_jogador)

	if SUPABASE_URL.contains("seu-projeto"):
		push_error("SupabaseManager: Configure SUPABASE_URL no código!")
		return false

	var corpo = {
		"nome": nome_jogador,
		"pontuacao": pontuacao,
		"resultado_id": resultado_id,
		"id_narrativa": id_narrativa,
		"stats": stats,
		"flags": flags,
		"data": Time.get_datetime_string_from_system()
	}

	var url = "%s/rest/v1/resultados" % SUPABASE_URL
	var headers = [
		"Content-Type: application/json",
		"apikey: %s" % SUPABASE_ANONKEY,
		"Authorization: Bearer %s" % SUPABASE_ANONKEY
	]

	var json = JSON.stringify(corpo)
	var resposta = await _fazer_request(url, headers, HTTPClient.METHOD_POST, json)
	if resposta[0] == -1:
		push_error("SupabaseManager: Erro ao enviar requisição: %d" % resposta[1])
		return false
	_processar_resposta(resposta)
	return true

# ─── API: Carregar ranking ─────────────────────────────────────────────────────

func carregar_ranking(limite: int = 10, id_narrativa: String = "") -> Array:
	print("SupabaseManager: Carregando ranking (top %d) para narrativa '%s'" % [limite, id_narrativa])

	if SUPABASE_URL.contains("seu-projeto"):
		push_error("SupabaseManager: Configure SUPABASE_URL no código!")
		return []

	var url: String
	var limit_param = ("&limit=%d" % limite) if limite > 0 else ""
	if id_narrativa == "":
		url = "%s/rest/v1/resultados?order=pontuacao.desc%s" % [SUPABASE_URL, limit_param]
	else:
		url = "%s/rest/v1/resultados?id_narrativa=eq.%s&order=pontuacao.desc%s" % [SUPABASE_URL, id_narrativa, limit_param]

	var headers = [
		"apikey: %s" % SUPABASE_ANONKEY,
		"Authorization: Bearer %s" % SUPABASE_ANONKEY
	]

	var resposta = await _fazer_request(url, headers)
	if resposta[0] == -1:
		push_error("SupabaseManager: Erro ao carregar ranking: %d" % resposta[1])
		return []
	return _processar_ranking(resposta)

# ─── Processamento de respostas ────────────────────────────────────────────────

func _processar_resposta(resposta) -> void:
	var status = resposta[1]
	var corpo = resposta[3]

	if status >= 200 and status < 300:
		print("SupabaseManager: Dados salvos com sucesso!")
	else:
		var texto = corpo.get_string_from_utf8() if corpo else ""
		push_error("SupabaseManager: Erro %d ao salvar - %s" % [status, texto])

func _processar_ranking(resposta) -> Array:
	var status = resposta[1]
	var corpo = resposta[3]

	if status != 200:
		push_error("SupabaseManager: Erro %d ao carregar ranking" % status)
		return []

	var texto = corpo.get_string_from_utf8()
	var json = JSON.new()
	json.parse(texto)
	var dados = json.get_data()

	if dados is Array:
		return dados
	return []
