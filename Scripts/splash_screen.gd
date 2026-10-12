extends Control

const TEMPO_LOGO := 1.0
const ESCALA_INICIAL := 0.98
const ESCALA_FINAL := 1.02

func _ready():
	$LogoIFTO.hide()
	$LogoPIBID.hide()
	$LogoJogo.hide()

	await mostrar_logo($LogoIFTO)
	await mostrar_logo($LogoPIBID)
	await mostrar_logo($LogoJogo)

	await TransicaoWipe.fechar()
	get_tree().change_scene_to_file("res://Scenes/menu_inical.tscn")

func mostrar_logo(logo: Control):
	logo.show()

	# Garante que o zoom acontece pelo centro
	logo.pivot_offset = logo.size / 2

	# Estado inicial
	logo.scale = Vector2(ESCALA_INICIAL, ESCALA_INICIAL)
	logo.modulate.a = 0.0

	# Fade + Zoom
	var tw = create_tween()

	tw.parallel().tween_property(
		logo,
		"scale",
		Vector2(ESCALA_FINAL, ESCALA_FINAL),
		TEMPO_LOGO
	)

	tw.parallel().tween_property(
		logo,
		"modulate:a",
		1.0,
		0.3
	)

	await TransicaoWipe.abrir()

	await get_tree().create_timer(TEMPO_LOGO).timeout

	await TransicaoWipe.fechar()

	logo.hide()
