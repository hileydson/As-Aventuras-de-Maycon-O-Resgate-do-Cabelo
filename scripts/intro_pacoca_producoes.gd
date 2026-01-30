extends VideoStreamPlayer
@onready var to_hide: Node2D = $".."

func _on_finished() -> void:
	pass #get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _process(delta):
	pass


func _on_node_2d_ready() -> void:
	await get_tree().create_timer(12.7).timeout
	#to_hide.visible = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
