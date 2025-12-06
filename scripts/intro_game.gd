extends VideoStreamPlayer


func go_to_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/demo_controls.tscn")

func _on_finished() -> void:
	go_to_game_scene()


func _process(delta):
	if Input.is_action_pressed("ui_accept"):
		go_to_game_scene()
