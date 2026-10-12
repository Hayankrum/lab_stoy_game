extends Node
class_name NarrativeSystem

# ─────────────────────────────────────────────
# ESTADO
# ─────────────────────────────────────────────

var estado := {
	# Base
	"moral":   0,
	"coragem": 0,
	"empatia": 0,
	# Sistema escolar
	"dicas":   0,
	"energia": 0,
	"lazer":   0,
	"social":  0,
	# Quiz
	"acertos": 0,
	"erros":   0
}

var flags             := {}
var final_executado   := false

# ─────────────────────────────────────────────
# RESET
# ─────────────────────────────────────────────

func resetar() -> void:
	estado = {
		# Base
		"moral":   0,
		"coragem": 0,
		"empatia": 0,
		# Sistema escolar
		"dicas":   0,
		"energia": 0,
		"lazer":   0,
		"social":  0,
		# Quiz
		"acertos": 0,
		"erros":   0
	}
	flags.clear()
	final_executado = false

# ─────────────────────────────────────────────
# EFEITOS
# ─────────────────────────────────────────────

func aplicar_efeitos(efeitos: Dictionary) -> void:
	for chave: String in efeitos:
		# FLAGS
		if chave.begins_with("flag:"):
			flags[chave] = efeitos[chave]
		# SET DIRETO
		elif chave.begins_with("set:"):
			var stat := chave.substr(4)
			if estado.has(stat):
				estado[stat] = int(efeitos[chave])
		# SOMA
		elif estado.has(chave):
			estado[chave] += int(efeitos[chave])
		else:
			push_warning("NarrativeSystem: chave desconhecida nos efeitos: '%s'" % chave)

# ─────────────────────────────────────────────
# CONDIÇÕES
# ─────────────────────────────────────────────

func checar(condicao: Dictionary) -> bool:
	for chave: String in condicao:
		# FLAG
		if chave.begins_with("flag:"):
			if flags.get(chave, false) != condicao[chave]:
				return false
		# MENOR QUE
		elif chave.ends_with("__lt"):
			var stat := chave.left(chave.length() - 4)
			if estado.get(stat, 0) >= int(condicao[chave]):
				return false
		# IGUAL
		elif chave.ends_with("__eq"):
			var stat := chave.left(chave.length() - 4)
			if estado.get(stat, 0) != int(condicao[chave]):
				return false
		# MAIOR OU IGUAL
		else:
			if estado.get(chave, 0) < int(condicao[chave]):
				return false
	return true

# ─────────────────────────────────────────────
# DEBUG
# ─────────────────────────────────────────────

func imprimir_estado() -> void:
	print("── NarrativeSystem ──────────────────")
	print("Estado : ", estado)
	print("Flags  : ", flags)
	print("─────────────────────────────────────")

# ─────────────────────────────────────────────
# FINAL
# ─────────────────────────────────────────────

func resolver_final(lista_finais: Array) -> Dictionary:
	if final_executado:
		return {}
	final_executado = true
	for final in lista_finais:
		var condicao: Dictionary = final.get("condicao", {})
		if condicao.is_empty() or checar(condicao):
			return {
				"id":    final.get("id",    "neutro"),
				"texto": final.get("texto", "FIM")
			}
	return {
		"id":    "neutro",
		"texto": "FIM"
	}
