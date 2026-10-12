extends Node

var cursor_normal
var cursor_click

var is_clicking := false

const CURSOR_SIZE := Vector2i(32, 32) # 👈 tamanho final do cursor

func _ready():
	cursor_normal = _load_resized("res://Assets/UI/curso0.png")
	cursor_click = _load_resized("res://Assets/UI/curso1.png")

	Input.set_custom_mouse_cursor(cursor_normal)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:

		if event.pressed:
			_set_cursor(cursor_click)
		else:
			_set_cursor(cursor_normal)

func _set_cursor(texture):
	if texture:
		Input.set_custom_mouse_cursor(texture)

func _load_resized(path: String) -> Texture2D:
	var img := Image.load_from_file(path)

	# redimensiona a imagem
	img.resize(CURSOR_SIZE.x, CURSOR_SIZE.y, Image.INTERPOLATE_LANCZOS)

	return ImageTexture.create_from_image(img)
