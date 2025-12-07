extends VideoStreamPlayer

func _on_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/batalha_2d.tscn")

func _process(delta):
	pass
