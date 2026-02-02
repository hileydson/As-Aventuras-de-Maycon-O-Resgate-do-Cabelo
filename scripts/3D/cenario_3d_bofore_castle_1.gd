extends Node3D



func _ready() -> void:
	get_tree().get_first_node_in_group("player").get_node("hud_canvas").visible = false
