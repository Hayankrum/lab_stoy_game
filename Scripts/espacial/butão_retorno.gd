extends TextureButton

@export var velocidade_hover := 0.15

@export var escala_hover := 1.08

func _ready():

	# CORREÇÃO: garante que o pivot de escala fique centralizado,
	# evitando que o botão se desloque ao fazer hover
	await get_tree().process_frame

	pivot_offset = size / 2

	pressed.connect(
		_voltar_historia
	)

	mouse_entered.connect(
		_mouse_enter
	)

	mouse_exited.connect(
		_mouse_exit
	)

func _voltar_historia():

	var historia = (
		get_tree()
		.get_first_node_in_group(
			"historia"
		)
	)

	if historia == null:

		push_error(
			"Historia não encontrada"
		)

		return

	historia.finalizar_interacao()

func _mouse_enter():

	var tween = create_tween()

	tween.tween_property(
		self,
		"scale",
		Vector2(
			escala_hover,
			escala_hover
		),
		velocidade_hover
	)

func _mouse_exit():

	var tween = create_tween()

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		velocidade_hover
	)
