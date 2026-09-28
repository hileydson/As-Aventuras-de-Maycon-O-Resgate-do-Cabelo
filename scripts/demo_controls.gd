extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.game_events["before_prologo"] = true
	Global.block_pause_before_prologo = true
	get_viewport().gui_disable_input = true
	await get_tree().create_timer(0.5).timeout
	get_viewport().gui_disable_input = false
	Global.block_pause_before_prologo = false
	get_tree().change_scene_to_file("res://scenes/intro_historia.tscn")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
