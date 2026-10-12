## DialogSystem.gd
## Cursor de diálogo sobre um array de entradas carregado do JSON.
## Usado pelo QuartoController para percorrer falas e escolhas.
##
## Entrada esperada no JSON (campo "dialogo"):
##   { "fala": "Texto aqui." }
##   { "fala": "Você pega o item.", "set": { "flag:tem_item": true } }
##   { "fala": "O que fazer?", "escolhas": [ ... ] }
##   { "condicao": { "moral": 2 }, "fala": "Você foi corajoso." }
##   { "fim": true }

extends Node
class_name DialogSystem

signal acabou

# ─── Estado ───────────────────────────────────────────────────────────────────

var _dialogo: Array = []
var index    := 0

# ─── API ──────────────────────────────────────────────────────────────────────

func iniciar(dados_quarto: Dictionary) -> void:
	_dialogo = dados_quarto.get("dialogo", [])
	index    = 0

func proximo() -> Variant:

	if index >= _dialogo.size():
		emit_signal("acabou")
		return null

	var entrada = _dialogo[index]
	index += 1
	return entrada

func pular_para(novo_index: int) -> void:
	index = novo_index
