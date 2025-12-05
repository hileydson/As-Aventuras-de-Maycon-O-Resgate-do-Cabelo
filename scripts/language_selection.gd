extends VBoxContainer

func _on_portugues_button_down() -> void:
	Global.default_language = Global.language_pt_br
	get_tree().change_scene_to_file("res://scenes/intro_pacoca_producoes.tscn")
	

func _on_ingles_button_down() -> void:
	Global.default_language = Global.language_en
	get_tree().change_scene_to_file("res://scenes/intro_pacoca_producoes.tscn")
