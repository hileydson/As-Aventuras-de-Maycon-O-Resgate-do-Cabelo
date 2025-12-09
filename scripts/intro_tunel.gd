extends VideoStreamPlayer

func _on_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_1.tscn")

func _process(delta):
	pass
