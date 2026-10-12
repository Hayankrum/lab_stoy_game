extends CanvasLayer

const DURACAO_FECHAR := 0.8
const DURACAO_ABRIR  := 0.8

var _overlay: ColorRect
var _mat: ShaderMaterial
var _ocupado := false

func _ready() -> void:
	_overlay = get_node_or_null("Overlay")

	if _overlay == null:
		push_error("TransicaoWipe: nó 'Overlay' não encontrado!")
		return

	_mat = _overlay.material as ShaderMaterial

	if _mat == null:
		push_error("TransicaoWipe: Overlay não tem ShaderMaterial!")
		return

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat.set_shader_parameter("direcao",   Vector2(1.0, 0.0))
	_mat.set_shader_parameter("invertido", false)
	_mat.set_shader_parameter("progresso", 0.0)

	get_tree().scene_changed.connect(_on_cena_mudou)

func _on_cena_mudou() -> void:
	# ✅ Garante que a tela continua coberta enquanto a cena monta
	_mat.set_shader_parameter("invertido", true)
	_mat.set_shader_parameter("progresso", 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	await abrir()

func fechar() -> void:
	if _mat == null or _ocupado:
		return
	_ocupado = true
	# ✅ Reseta aqui antes de começar
	_mat.set_shader_parameter("invertido", false)
	_mat.set_shader_parameter("progresso", 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await _animar(0.0, 1.0, DURACAO_FECHAR)

func abrir() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("invertido", true)
	await _animar(0.0, 1.0, DURACAO_ABRIR)
	# ✅ Sem reset aqui — a tela some naturalmente no fim da animação
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ocupado = false

func executar(acao: Callable, _direcao: Vector2 = Vector2.ZERO) -> void:
	await fechar()
	acao.call()
	await abrir()

func _animar(de: float, ate: float, dur: float) -> void:
	var tw = create_tween()
	tw.tween_method(
		func(v: float): _mat.set_shader_parameter("progresso", v),
		de, ate, dur
	)
	await tw.finished
