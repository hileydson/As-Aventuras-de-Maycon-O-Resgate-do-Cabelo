extends VideoStreamPlayer
@onready var menu_song: AudioStreamPlayer2D = $menu_song


func go_to_menu_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_finished() -> void:
	go_to_menu_scene()

func _process(delta):
	if Input.is_action_pressed("ui_accept"):
		go_to_menu_scene()
