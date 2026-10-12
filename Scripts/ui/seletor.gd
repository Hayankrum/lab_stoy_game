extends BaseButton

@export_file("*.tscn")
var cena_destino: String

@export var id_historia: String = ""

@export var preview: TextureRect
@export var painel_descricao: Control
@export var label_descricao: Label

@export_multiline
var descricao: String = ""

var tween_flutuar: Tween
var pos_preview_original: Vector2
var dialog_nome: Control


func _ready():
	if preview:
		preview.visible = false
		pos_preview_original = preview.position

	if painel_descricao:
		painel_descricao.visible = false
		painel_descricao.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_criar_dialog_nome()

	mouse_entered.connect(_ao_entrar)
	mouse_exited.connect(_ao_sair)
	pressed.connect(_ao_clicar)


func _criar_dialog_nome() -> void:
	# Overlay escuro cobrindo a tela inteira
	var overlay = ColorRect.new()
	overlay.name = "DialogNome"
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	# Painel central branco
	var painel = PanelContainer.new()
	painel.custom_minimum_size = Vector2(300, 0)
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left   = 24
	style.content_margin_right  = 24
	style.content_margin_top    = 20
	style.content_margin_bottom = 20
	painel.add_theme_stylebox_override("panel", style)

	# Conteúdo vertical
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = "Como você se chama?"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	vbox.add_child(label)

	var input = LineEdit.new()
	input.name = "InputNome"
	input.placeholder_text = "Seu nome..."
	input.custom_minimum_size = Vector2(0, 36)

	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.95, 0.95, 0.95)
	input_style.border_width_bottom = 2
	input_style.border_color = Color(0.75, 0.75, 0.75)
	input_style.corner_radius_top_left    = 6
	input_style.corner_radius_top_right   = 6
	input_style.corner_radius_bottom_left = 6
	input_style.corner_radius_bottom_right = 6
	input_style.content_margin_left  = 10
	input_style.content_margin_right = 10
	input.add_theme_stylebox_override("normal", input_style)
	input.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	vbox.add_child(input)

	var btn = Button.new()
	btn.text = "Começar"
	btn.custom_minimum_size = Vector2(0, 36)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.18, 0.18)
	btn_style.corner_radius_top_left    = 6
	btn_style.corner_radius_top_right   = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", _btn_style_hover())
	btn.add_theme_stylebox_override("pressed", btn_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)

	btn.pressed.connect(func():
		_processar_nome(input.text)
	)
	input.text_submitted.connect(func(txt):
		_processar_nome(txt)
	)

	vbox.add_child(btn)
	painel.add_child(vbox)
	overlay.add_child(painel)

	# Fecha ao clicar fora do painel
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if not painel.get_global_rect().has_point(event.global_position):
				overlay.visible = false
	)

	dialog_nome = overlay
	get_tree().root.call_deferred("add_child", overlay)


func _btn_style_hover() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.30, 0.30, 0.30)
	s.corner_radius_top_left    = 6
	s.corner_radius_top_right   = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	return s


func _ao_entrar():
	if preview:
		preview.visible = true

		preview.position = pos_preview_original

		preview.modulate.a = 0.0
		preview.scale = Vector2(0.95, 0.95)

		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_QUAD)

		tw.parallel().tween_property(preview, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(preview, "scale", Vector2.ONE, 0.2)

		if tween_flutuar:
			tween_flutuar.kill()

		tween_flutuar = create_tween()
		tween_flutuar.set_loops()

		tween_flutuar.tween_property(
			preview,
			"position",
			pos_preview_original + Vector2(0, -8),
			1.0
		)

		tween_flutuar.tween_property(
			preview,
			"position",
			pos_preview_original + Vector2(0, 8),
			1.0
		)

	if painel_descricao:
		painel_descricao.visible = true

		if label_descricao:
			label_descricao.text = descricao

		painel_descricao.modulate.a = 0.0
		painel_descricao.scale = Vector2(0.95, 0.95)

		var tw_painel = create_tween()
		tw_painel.set_ease(Tween.EASE_OUT)
		tw_painel.set_trans(Tween.TRANS_BACK)

		tw_painel.parallel().tween_property(
			painel_descricao,
			"modulate:a",
			1.0,
			0.25
		)

		tw_painel.parallel().tween_property(
			painel_descricao,
			"scale",
			Vector2.ONE,
			0.25
		)


func _ao_sair():
	if tween_flutuar:
		tween_flutuar.kill()

	if preview:
		var tw = create_tween()
		tw.set_ease(Tween.EASE_IN)

		tw.parallel().tween_property(preview, "modulate:a", 0.0, 0.15)
		tw.parallel().tween_property(preview, "scale", Vector2(0.95, 0.95), 0.15)

		await tw.finished

		if is_instance_valid(preview):
			preview.position = pos_preview_original
			preview.visible = false

	if painel_descricao:
		var tw_painel = create_tween()
		tw_painel.set_ease(Tween.EASE_IN)
		tw_painel.set_trans(Tween.TRANS_QUAD)

		tw_painel.parallel().tween_property(painel_descricao, "modulate:a", 0.0, 0.15)
		tw_painel.parallel().tween_property(painel_descricao, "scale", Vector2(0.95, 0.95), 0.15)

		await tw_painel.finished

		if is_instance_valid(painel_descricao):
			painel_descricao.visible = false


func _atualizar_estado_botao() -> void:
	var historia_ja_jogada = not PlayerData.pode_jogar_historia(id_historia)

	disabled = historia_ja_jogada

	if historia_ja_jogada:
		modulate.a = 0.5
	else:
		modulate.a = 1.0


func _ao_clicar():
	if cena_destino.is_empty():
		return

	if not PlayerData.pode_jogar_historia(id_historia):
		push_warning("Você já completou essa história!")
		return

	if PlayerData.nome_jogador == "":
		dialog_nome.visible = true
		var input = dialog_nome.find_child("InputNome")
		if input:
			input.grab_focus()
	else:
		_carregar_cena()


func _processar_nome(nome: String) -> void:
	var nome_limpo = nome.strip_edges()

	if nome_limpo == "":
		push_warning("Nome não pode ficar vazio!")
		return

	if dialog_nome:
		dialog_nome.visible = false

	PlayerData.definir_nome(nome_limpo)
	_carregar_cena()


func _carregar_cena() -> void:
	PlayerData.definir_narrativa_atual(id_historia)

	PlayerData.registrar_historia_jogada(id_historia)
	_atualizar_estado_botao()

	if has_node("/root/TransicaoWipe"):
		await TransicaoWipe.fechar()

	get_tree().change_scene_to_file(cena_destino)
