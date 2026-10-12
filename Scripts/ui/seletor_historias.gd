extends TextureButton

@export_file("*.tscn") var proxima_scene

func _pressed():
	get_tree().change_scene_to_file(proxima_scene)
