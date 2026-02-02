extends Node3D
@onready var sangue_fill_effect: AudioStreamPlayer = $SangueFillEffect
@onready var sliding: AudioStreamPlayer = $Sliding



func _ready() -> void:
	get_tree().get_first_node_in_group("player").get_node("hud_canvas").visible = false
	
	sliding.play()
	await get_tree().create_timer(2.1).timeout
	sangue_fill_effect.play()
	sliding.stop()
	get_tree().get_first_node_in_group("player").aplicar_shake(0.9)
